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

    def handle_request(payload, _routing_key, _opts, state) do
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
  requests to, declare a exclusive server-named queue to receive responses, and consume
  that server-named queue.

  Every time a channel is open the context is set up, meaning that the exchange and
  a new server-named queue are declared, and the queue is consumed through the
  new channel based on the given configuration.

  The configuration must be a `Keyword.t` that contains a single key: `:exchange`
  whose value is the configuration for the `Hare.Context.Action.DeclareExchange`.
  Check it for more detailed information.
  """

  @type payload     :: Hare.Adapter.payload
  @type routing_key :: Hare.Adapter.routing_key
  @type opts        :: Hare.Adapter.opts
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
  Called every time the channel has been opened, the exchange and the
  server-named queue declared, and the queue consumed.

  It is called with two arguments: some metadata and the process' internal state.

  The metadata is a map with the following fields:

    * `:req_exchange` - the `Hare.Core.Exchange` to issue requests to
    * `:resp_queue` - the server-named `Hare.Core.Queue` to consume the responses from

  Returning `{:noreply, state}` will cause the process to enter the main loop
  with `state` as its internal state.

  Returning `{:stop, reason, state}` will terminate the loop and call
  `terminate(reason, state)` before the process exists with reason `reason`.
  """
  @callback connected(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when the AMQP server has registered the process as a consumer of the
  server-named queue and it will start to receive messages.

  Returning `{:noreply, state}` will causes the process to enter the main loop
  with the given state.

  Returning `{:stop, reason, state}` will not send the message, terminate the
  main loop and call `terminate(reason, state)` before the process exists with
  reason `reason`.
  """
  @callback handle_ready(meta, state) ::
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

  Returning `{:stop, reason, state}` will not send the message, terminate the
  main loop and call `terminate(reason, state)` before the process exists with
  reason `reason`.
  """
  @callback handle_request(payload, routing_key, opts :: term, state) ::
              {:ok, state} |
              {:ok, payload, routing_key, opts :: term, state} |
              {:reply, response :: term, state} |
              {:stop, reason :: term, response :: binary, state}

  @doc """
  Called when the process receives a message.

  Returning `{:noreply, state}` will causes the process to enter the main loop
  with the given state.

  Returning `{:stop, reason, state}` will not send the message, terminate the
  main loop and call `terminate(reason, state)` before the process exists with
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
      def connected(_meta, state),
        do: {:noreply, state}

      @doc false
      def handle_ready(_meta, state),
        do: {:noreply, state}

      @doc false
      def handle_request(_payload, _routing_key, _meta, state),
        do: {:ok, state}

      @doc false
      def handle_info(_message, state),
        do: {:noreply, state}

      @doc false
      def terminate(_reason, _state),
        do: :ok

      defoverridable [init: 1, terminate: 2, connected: 2,
                      handle_ready: 2, handle_request: 4, handle_info: 2]
    end
  end

  use Connection

  alias __MODULE__.{Declaration, Runtime, State}
  alias Hare.Core.{Chan, Queue, Exchange}

  @context Hare.Context

  @type config :: [exchange: Hare.Context.Action.DeclareExchange.config]

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
    args = {mod, conn, config, context,  initial}

    Connection.start_link(__MODULE__, args, opts)
  end

  @doc """
  Performs a RPC request and blocks until the response arrives.

  A timeout bound to the same rules as the `GenServer` timeout may be
  specified (5 seconds by default)
  """
  @spec request(GenServer.server, payload, routing_key, opts, timeout) ::
          {:ok, response :: binary} |
          {:error, reason :: term}
  def request(client, payload, routing_key \\ "", opts \\ [], timeout \\ 5000),
    do: Connection.call(client, {:request, payload, routing_key, opts}, timeout)

  @doc false
  def init({mod, conn, config, context, initial}) do
    with {:ok, declaration}  <- Declaration.parse(config, context),
         {:ok, runtime_opts} <- Runtime.parse(config),
         {:ok, given}        <- mod.init(initial) do
      {:connect, :init, State.new(conn, declaration, runtime_opts, mod, given)}
    else
      {:error, reason} -> {:stop, {:config_error, reason, config}}
      other            -> other
    end
  end

  @doc false
  def connect(_info, %{conn: conn, declaration: declaration} = state) do
    with {:ok, chan}                     <- Chan.open(conn),
         {:ok, resp_queue, req_exchange} <- Declaration.run(declaration, chan),
         {:ok, new_resp_queue}           <- Queue.consume(resp_queue, no_ack: true) do
      handle_connected(state, chan, new_resp_queue, req_exchange)
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  defp handle_connected(%{mod: mod, given: given} = state, chan, resp_queue, req_exchange) do
    ref  = Chan.monitor(chan)
    meta = complete(%{}, state)

    case mod.connected(meta, given) do
      {:noreply, new_given} ->
        {:ok, State.connected(state, chan, ref, resp_queue, req_exchange, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.connected(state, chan, ref, resp_queue, req_exchange, new_given)}
    end
  end

  @doc false
  def disconnect(_info, state),
    do: {:stop, :normal, state}

  @doc false
  def handle_call({:request, payload, routing_key, opts}, from, %{mod: mod, given: given} = state) do
    case mod.handle_request(payload, routing_key, opts, given) do
      {:ok, new_given} ->
        correlation_id = perform(payload, routing_key, opts, state)
        set_request_timeout(correlation_id, state)
        {:noreply, State.set(state, new_given, correlation_id, from)}

      {:ok, new_payload, new_routing_key, new_opts, new_given} ->
        correlation_id = perform(new_payload, new_routing_key, new_opts, state)
        {:noreply, State.set(state, new_given, correlation_id, from)}

      {:reply, response, new_given} ->
        {:reply, {:ok, response}, State.set(state, new_given)}

      {:stop, reason, response, new_given} ->
        {:stop, reason, {:ok, response}, State.set(state, new_given)}
    end
  end

  @doc false
  def handle_info({:DOWN, ref, _, _, _reason}, %{status: :connected, ref: ref} = state) do
    {:connect, :down, State.chan_down(state)}
  end
  def handle_info({:request_timeout, correlation_id}, state) do
    case State.pop_waiting(state, correlation_id) do
      {:ok, from, new_state} ->
        GenServer.reply(from, {:error, :timeout})
        {:noreply, new_state}

      :unknown ->
        {:noreply, state}
    end
  end
  def handle_info(message, %{status: :connected, resp_queue: queue} = state) do
    case Queue.handle(queue, message) do
      {:consume_ok, meta} ->
        handle_mod_ready(meta, state)

      {:deliver, payload, meta} ->
        handle_response(payload, meta, state)

      {:cancel_ok, _meta} ->
        {:stop, :cancelled, state}

      :unknown ->
        handle_mod_info(message, state)
    end
  end
  def handle_info(message, state) do
    handle_mod_info(message, state)
  end

  @doc false
  def terminate(reason, %{status: :connected, chan: chan} = state) do
    mod_terminate(reason, state)
    Chan.close(chan)
  end
  def terminate(reason, state) do
    mod_terminate(reason, state)
  end

  defp mod_terminate(reason, %{mod: mod, given: given}),
    do: mod.terminate(reason, given)

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
        GenServer.reply(from, {:ok, payload})
        {:noreply, new_state}

      :unknown ->
        {:noreply, state}
    end
  end

  defp handle_mod_info(message, %{mod: mod, given: given} = state) do
    case mod.handle_info(message, given) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  defp perform(payload, routing_key, opts, %{req_exchange: req_exchange, resp_queue: resp_queue}) do
    correlation_id = generate_correlation_id()
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
end
