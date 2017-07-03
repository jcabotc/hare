defmodule Hare.RPC.Client do
  @moduledoc """
  A behaviour module for implementing AMQP RPC client processes.

  The `Hare.RPC.Client` module provides a way to create processes that hold,
  monitor, and restart a channel in case of failure, exports a function perform
  RPC to an exchange and receive the response, and some callbacks to hook into
  the process lifecycle.

  An example `Hare.RPC.Client` process that performs a RPC request and returns
  the response, but returns `"already_requested"` when a request with the same
  payload has already been performed.

  ```
  defmodule MyRPCClient do
    use Hare.RPC.Client

      def start_link(conn, config, opts \\ []) do
      Hare.RPC.Client.start_link(__MODULE__, conn, config, :ok, opts)
    end

    def init(:ok) do
      {:ok, MapSet.new}
    end

    def before_request(payload, _routing_key, _opts, state) do
      case MapSet.member?(cache, payload) do
        {:ok, response} -> {:reply, "already_requested", state}
        :error          -> {:ok, MapSet.put(state, payload)}
      end
    end
  end
  ```

  ## Channel handling

  When the `Hare.RPC.Client` starts with `start_link/5` it runs the `init/1` callback
  and responds with `{:ok, pid}` on success, like a GenServer.

  After starting the process it attempts to open a channel on the given connection.
  It monitors the channel, and in case of failure it tries to reopen again and again
  on the same connection.

  ## Context setup

  The context setup process for a RPC client is to declare the exchange to perform
  requests to, declare a exclusive server-named queue to receive responses, and consume that server-named queue.

  Every time a channel is open the context is set up, meaning that the exchange and
  a new server-named queue are declared, and the queue is consumed through the
  new channel based on the given configuration.

  The configuration must be a `Keyword.t` that contains a single key: `:exchange`
  whose value is the configuration for the `Hare.Context.Action.DeclareExchange`.
  Check it for more detailed information.
  """

  @type request     :: term
  @type payload     :: Hare.Adapter.payload
  @type response    :: term
  @type routing_key :: Hare.Adapter.routing_key
  @type opts        :: Hare.Adapter.opts
  @type from        :: GenServer.from
  @type meta        :: map
  @type state       :: term

  @doc """
  Called when the RPC client process is first started. `start_link/5` will block
  until it returns.

  It receives as argument the fourth argument given to `start_link/5`.

  Returning `{:ok, state}` will cause `start_link/5` to return `{:ok, pid}`
  and attempt to open a channel on the given connection, declare the exchange,
  declare a server-named queue, and consume it.
  After that it will enter the main loop with `state` as its internal state.

  Returning `:ignore` will cause `start_link/5` to return `:ignore` and the
  process will exit normally without entering the loop, opening a channel or calling
  `terminate/2`.

  Returning `{:stop, reason}` will cause `start_link/5` to return `{:error, reason}` and
  the process will exit with reason `reason` without entering the loop, opening a channel,
  or calling `terminate/2`.
  """
  @callback init(initial :: term) ::
              {:ok, state} |
              :ignore |
              {:stop, reason :: term}

  @doc """
  Called when the RPC client process has opened AMQP channel before registering
  itself as a consumer.

  Returning `{:noreply, state}` will cause the process to enter the main loop
  with the given state.

  Returning `{:stop, reason, state}` will terminate the main loop and call
  `terminate(reason, state)` before the process exits with reason `reason`.
  """
  @callback handle_connected(state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when the AMQP server has registered the process as a consumer of the
  server-named queue and it will start to receive messages.

  Returning `{:noreply, state}` will cause the process to enter the main loop
  with the given state.

  Returning `{:stop, reason, state}` will not send the message, terminate the
  main loop and call `terminate(reason, state)` before the process exits with
  reason `reason`.
  """
  @callback handle_ready(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when the AMQP server has been disconnected from the AMQP broker.

  Returning `{:noreply, state}` will cause the process to enter the main loop
  with the given state. The server will not consume any new messages until
  connection to AMQP broker is restored.

  Returning `{:stop, reason, state}` will terminate the main loop and call
  `terminate(reason, state)` before the process exits with reason `reason`.
  """
  @callback handle_disconnected(reason :: term, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @doc """
  Called before a request will be performed to the exchange.

  It receives as argument the message payload, the routing key, the options
  for that publication and the internal state.

  Returning `{:ok, state}` will cause the request to be performed with no
  modification, block the client until the response is received, and enter
  the main loop with the given state.

  Returning `{:ok, payload, routing_key, opts, state}` will cause the
  given payload, routing key and options to be used instead of the original
  ones, block the client until the response is received, and enter
  the main loop with the given state.

  Returning `{:reply, response, state}` will respond the client inmediately
  without performing the request with the given response, and enter the main
  loop again with the given state.

  Returning `{:stop, reason, response, state}` will not send the message,
  respond to the caller with `response`, and terminate the main loop
  and call `terminate(reason, state)` before the process exits with
  reason `reason`.

  Returning `{:stop, reason, state}` will not send the message, terminate the
  main loop and call `terminate(reason, state)` before the process exits with
  reason `reason`.
  """
  @callback before_request(request, routing_key, opts :: term, from, state) ::
              {:ok, state} |
              {:ok, payload, routing_key, opts :: term, state} |
              {:reply, response, state} |
              {:stop, reason :: term, response, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when a response has been received, before it is delivered to the caller.

  It receives as argument the message payload, the routing key, the options
  for that publication, the response, and the internal state.

  Returning `{:reply, reply, state}` will cause the given reply to be
  delivered to the caller instead of the original response, and enter
  the main loop with the given state.

  Returning `{:noreply, state}` will enter the main loop with the given state
  without responding to the caller (that will eventually timeout or keep blocked
  forever if the timeout was set to `:infinity`).

  Returning `{:stop, reason, reply, state}` will deliver the given reply to
  the caller instead of the original response and call `terminate(reason, state)`
  before the process exits with reason `reason`.

  Returning `{:stop, reason, state}` not reply to the caller and call
  `terminate(reason, state)` before the process exits with reason `reason`.
  """
  @callback on_response(response, from, state) ::
              {:reply, response, state} |
              {:noreply, state} |
              {:stop, reason :: term, response, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when a message has been returned. It may happen when a request is sent
  with option `mandatory: true` and broker cannot deliver the message to a queue.

  It receives as argument the  caller reference and the internal state.

  Returning `{:reply, reply, state}` will cause the given reply to be
  delivered to the caller instead of the original response, and enter
  the main loop with the given state.

  Returning `{:noreply, state}` will enter the main loop with the given state
  without responding to the caller (that will eventually timeout or keep blocked
  forever if the timeout was set to `:infinity`).

  Returning `{:stop, reason, reply, state}` will deliver the given reply to
  the caller instead of the original response and call `terminate(reason, state)`
  before the process exits with reason `reason`.

  Returning `{:stop, reason, state}` not reply to the caller and call
  `terminate(reason, state)` before the process exits with reason `reason`.
  """
  @callback on_return(payload, state) ::
              {:reply, response, state} |
              {:noreply, state} |
              {:stop, reason :: term, response, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when a request has timed out.

  It receives as argument the message payload, the routing key, the options
  for that publication, and the internal state.

  Returning `{:reply, reply, state}` will cause the given reply to be
  delivered to the caller, and enter the main loop with the given state.

  Returning `{:noreply, state}` will enter the main loop with the given state
  without responding to the caller (that will eventually timeout or keep blocked
  forever if the timeout was set to `:infinity`).

  Returning `{:stop, reason, reply, state}` will deliver the given reply to
  the caller, and call `terminate(reason, state)` before the process exits
  with reason `reason`.

  Returning `{:stop, reason, state}` will not reply to the caller and call
  `terminate(reason, state)` before the process exits with reason `reason`.
  """
  @callback on_timeout(from, state) ::
              {:reply, response, state} |
              {:noreply, state} |
              {:stop, reason :: term, response, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when the process receives a call message sent by `call/3`. This
  callback has the same arguments as the `GenServer` equivalent and the
  `:reply`, `:noreply` and `:stop` return tuples behave the same.
  """
  @callback handle_call(request :: term, GenServer.from, state) ::
              {:reply, reply :: term, state} |
              {:reply, reply :: term, state, timeout | :hibernate} |
              {:noreply, state} |
              {:noreply, state, timeout | :hibernate} |
              {:stop, reason :: term, state} |
              {:stop, reason :: term, reply :: term, state}

  @doc """
  Called when the process receives a cast message sent by `cast/3`. This
  callback has the same arguments as the `GenServer` equivalent and the
  `:noreply` and `:stop` return tuples behave the same.
  """
  @callback handle_cast(request :: term, state) ::
              {:noreply, state} |
              {:noreply, state, timeout | :hibernate} |
              {:stop, reason :: term, state}

  @doc """
  Called when the process receives a message.

  Returning `{:noreply, state}` will causes the process to enter the main loop
  with the given state.

  Returning `{:stop, reason, state}` will not send the message, terminate the
  main loop and call `terminate(reason, state)` before the process exits with
  reason `reason`.
  """
  @callback handle_info(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @doc """
  This callback is the same as the `GenServer` equivalent and is called when the
  process terminates. The first argument is the reason the process is about
  to exit with.
  """
  @callback terminate(reason :: term, state) ::
              any

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      @behaviour Hare.RPC.Client

      @doc false
      def init(initial),
        do: {:ok, initial}

      @doc false
      def handle_connected(state),
        do: {:noreply, state}

      @doc false
      def handle_ready(_meta, state),
        do: {:noreply, state}

      @doc false
      def handle_disconnected(_reason, state),
        do: {:noreply, state}

      @doc false
      def before_request(_payload, _routing_key, _meta, _from, state),
        do: {:ok, state}

      @doc false
      def on_timeout(_from, state),
        do: {:reply, {:error, :timeout}, state}

      @doc false
      def on_response(response, _from, state),
        do: {:reply, {:ok, response}, state}

      @doc false
      def on_return(_from, state),
        do: {:reply, {:error, :returned}, state}

      @doc false
      def handle_call(message, _from, state),
        do: {:stop, {:bad_call, message}, state}

      @doc false
      def handle_cast(message, state),
        do: {:stop, {:bad_cast, message}, state}

      @doc false
      def handle_info(_message, state),
        do: {:noreply, state}

      @doc false
      def terminate(_reason, _state),
        do: :ok

      defoverridable [init: 1, terminate: 2,
                      handle_connected: 1, handle_ready: 2, handle_disconnected: 2,
                      handle_call: 3, handle_cast: 2, handle_info: 2,
                      before_request: 5, on_timeout: 2, on_return: 2, on_response: 3]
    end
  end

  use Hare.Actor

  alias __MODULE__.{Declaration, Runtime, State}
  alias Hare.Core.{Queue, Exchange, Chan}

  @context Hare.Context

  @type config :: [exchange: Hare.Context.Action.DeclareExchange.config,
                   context: module,
                   timeout: timeout]

  @doc """
  Starts a `Hare.RPC.Client` process linked to the current process.

  This function is used to start a `Hare.RPC.Client` process in a supervision
  tree. The process will be started by calling `init` with the given initial
  value.

  Arguments:

    * `mod` - the module that defines the server callbacks (like GenServer)
    * `conn` - the pid of a `Hare.Core.Conn` process
    * `config` - the configuration of the publisher (describing the exchange to declare)
    * `initial` - the value that will be given to `init/1`
    * `opts` - the GenServer options
  """
  @spec start_link(module, GenServer.server, config, initial :: term, GenServer.options) :: GenServer.on_start
  def start_link(mod, conn, config, initial, opts \\ []) do
    {context, opts} = Keyword.pop(opts, :context, @context)
    args = {config, context, mod, initial}

    Hare.Actor.start_link(__MODULE__, conn, args, opts)
  end

  @doc """
  Performs a RPC request and blocks until the response arrives.

  A timeout bound to the same rules as the `GenServer` timeout may be
  specified (5 seconds by default)
  """
  @spec request(GenServer.server, request, routing_key, opts, timeout) ::
          {:ok, response} |
          {:error, reason :: term}
  def request(client, payload, routing_key \\ "", opts \\ [], timeout \\ 5000),
    do: Hare.Actor.call(client, {:"$hare_request", payload, routing_key, opts}, timeout)

  defdelegate call(server, message),          to: Hare.Actor
  defdelegate call(server, message, timeout), to: Hare.Actor
  defdelegate cast(server, message),          to: Hare.Actor
  defdelegate reply(from, message),           to: Hare.Actor

  @doc false
  def init({config, context, mod, initial}) do
    with {:ok, declaration}  <- build_declaration(config, context),
         {:ok, runtime_opts} <- parse_runtime(config),
         {:ok, given}        <- mod_init(mod, initial) do
      {:ok, State.new(config, declaration, runtime_opts, mod, given)}
    end
  end

  defp build_declaration(config, context) do
    with {:error, reason} <- Declaration.parse(config, context) do
      {:stop, {:config_error, reason, config}}
    end
  end

  defp parse_runtime(config) do
    with {:error, reason} <- Runtime.parse(config) do
      {:stop, {:config_error, reason, config}}
    end
  end

  defp mod_init(mod, initial) do
    case mod.init(initial) do
      {:ok, given}    -> {:ok, given}
      :ignore         -> :ignore
      {:stop, reason} -> {:stop, reason}
    end
  end

  @doc false
  def connected(chan, %{declaration: declaration, mod: mod, given: given} = state) do
    with {:noreply, new_given}           <- mod.handle_connected(given),
         new_state                       <- State.set(state, new_given),
         {:ok, resp_queue, req_exchange} <- Declaration.run(declaration, chan),
         {:ok, new_resp_queue}           <- Queue.consume(resp_queue, no_ack: true),
         :ok                             <- Chan.register_return_handler(chan) do
      {:ok, State.connected(new_state, chan, new_resp_queue, req_exchange)}
    else
      {:stop, reason, new_given} -> {:stop, reason, State.set(state, new_given)}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  @doc false
  def disconnected(reason, %{mod: mod, given: given} = state) do
    new_state =
      state
      |> State.clear_waiting(&GenServer.reply(&1, {:error, :disconnected}))
      |> State.disconnected()

    case mod.handle_disconnected(reason, given) do
      {:noreply, new_given} ->
        {:ok, State.set(new_state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(new_state, new_given)}
    end
  end

  @doc false
  def handle_call({:"$hare_request", _payload, _routing_key, _opts}, _from, %{connected: false} = state) do
    {:reply, {:error, :not_connected}, state}
  end
  def handle_call({:"$hare_request", payload, routing_key, opts}, from, %{mod: mod, given: given} = state) do
    correlation_id = generate_correlation_id()
    opts = Keyword.put(opts, :correlation_id, correlation_id)

    case mod.before_request(payload, routing_key, opts, from, given) do
      {:ok, new_given} ->
        perform(correlation_id, payload, routing_key, opts, state)
        set_request_timeout(correlation_id, state)
        {:noreply, State.set(state, new_given, correlation_id, from)}

      {:ok, new_payload, new_routing_key, new_opts, new_given} ->
        perform(correlation_id, new_payload, new_routing_key, new_opts, state)
        set_request_timeout(correlation_id, state)
        {:noreply, State.set(state, new_given, correlation_id, from)}

      {:reply, response, new_given} ->
        {:reply, response, State.set(state, new_given)}

      {:stop, reason, response, new_given} ->
        {:stop, reason, response, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end
  def handle_call(message, from, %{mod: mod, given: given} = state) do
    case mod.handle_call(message, from, given) do
      {:reply, reply, new_given} ->
        {:reply, reply, State.set(state, new_given)}

      {:reply, reply, new_given, timeout} ->
        {:reply, reply, State.set(state, new_given), timeout}

      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:noreply, new_given, timeout} ->
        {:noreply, State.set(state, new_given), timeout}

      {:stop, reason, reply, new_given} ->
        {:stop, reason, reply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  @doc false
  def handle_cast(message, state),
    do: handle_async(message, :handle_cast, state)

  @doc false
  def handle_info({:request_timeout, correlation_id}, state) do
    case State.pop_waiting(state, correlation_id) do
      {:ok, from, new_state} ->
        handle_sync(:on_timeout, from, new_state)

      :unknown ->
        {:noreply, state}
    end
  end
  def handle_info(message, %{resp_queue: queue} = state) do
    case Queue.handle(queue, message) do
      {:consume_ok, meta} ->
        handle_mod_ready(meta, state)

      {:deliver, payload, meta} ->
        handle_response(payload, meta, state)

      {:cancel_ok, _meta} ->
        {:stop, {:shutdown, :cancelled}, state}

      {:cancel, _meta} ->
        {:stop, :cancelled, state}

      {:return, payload, meta} ->
        handle_return(payload, meta, state)

      :unknown ->
        handle_async(message, :handle_info, state)
    end
  end
  def handle_info(message, state),
    do: handle_async(message, :handle_info, state)

  @doc false
  def terminate(reason, %{chan: chan, mod: mod, given: given}) do
    if chan, do: Chan.unregister_return_handler(chan)
    mod.terminate(reason, given)
  end

  defp handle_mod_ready(meta, %{mod: mod, given: given} = state) do
    case mod.handle_ready(complete(meta, state), given) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  defp handle_response(payload, %{correlation_id: correlation_id}, state) do
    case State.pop_waiting(state, correlation_id) do
      {:ok, from, new_state} ->
        handle_sync(:on_response, [payload], from, new_state)

      :unknown ->
        {:noreply, state}
    end
  end

  defp handle_return(_payload, %{correlation_id: correlation_id}, state) do
    case State.pop_waiting(state, correlation_id) do
      {:ok, from, new_state} ->
        handle_sync(:on_return, from, new_state)

      :unknown ->
        {:noreply, state}
    end
  end

  defp perform(correlation_id, payload, routing_key, opts, %{req_exchange: req_exchange, resp_queue: resp_queue}) do
    new_opts = Keyword.merge(opts, reply_to:       resp_queue.name,
                                   correlation_id: correlation_id)

    Exchange.publish(req_exchange, payload, routing_key, new_opts)
    correlation_id
  end

  defp generate_correlation_id do
    :erlang.unique_integer
    |> :erlang.integer_to_binary
    |> Base.encode64
  end

  defp complete(meta, %{resp_queue: resp_queue, req_exchange: req_exchange}) do
    meta
    |> Map.put(:req_exchange, req_exchange)
    |> Map.put(:resp_queue, resp_queue)
  end

  defp set_request_timeout(correlation_id, %{runtime_opts: %{timeout: timeout}}) do
    if timeout != :infinity,
      do: Process.send_after(self(), {:request_timeout, correlation_id}, timeout)
  end

  defp handle_async(message, fun, %{mod: mod, given: given} = state) do
    case apply(mod, fun, [message, given]) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:noreply, new_given, timeout} ->
        {:noreply, State.set(state, new_given), timeout}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  defp handle_sync(fun, args \\ [], from, %{mod: mod, given: given} = state) do
    case apply(mod, fun, args ++ [from, given]) do
      {:reply, response, new_given} ->
        GenServer.reply(from, response)
        {:noreply, State.set(state, new_given)}

      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, response, new_given} ->
        GenServer.reply(from, response)
        {:stop, reason, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end
end
