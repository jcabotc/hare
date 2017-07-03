defmodule Hare.RPC.Server do
  @moduledoc """
  A behaviour module for implementing AMQP RPC server processes.

  The `Hare.RPC.Server` module provides a way to create processes that hold,
  monitor, and restart a channel in case of failure, and have some callbacks
  to hook into the process lifecycle and handle messages.

  An example `Hare.RPC.Server` process that responds messages with `"ping"` as
  payload with a `"pong"` response, otherwise it does not ack but calls a given
  handler function with the payload and a callback function, so the handler can
  respond when the message is processed:

  ```
  defmodule MyRPC.Server do
    use Hare.RPC.Server

    def start_link(conn, config, handler) do
      Hare.RPC.Server.start_link(__MODULE__, conn, config, handler)
    end

    def init(handler) do
      {:ok, %{handler: handler}}
    end

    def handle_request("ping", _meta, state) do
      {:reply, "pong", state}
    end
    def handle_request(payload, meta, %{handler: handler} = state) do
      callback = &Hare.RPC.Server.reply(meta, &1)

      handler.(payload, callback)
      {:noreply, state}
    end
  end
  ```

  ## Channel handling

  When the `Hare.RPC.Server` starts with `start_link/5` it runs the `init/1` callback
  and responds with `{:ok, pid}` on success, like a GenServer.

  After starting the process it attempts to open a channel on the given connection.
  It monitors the channel, and in case of failure it tries to reopen again and again
  on the same connection.

  ## Context setup

  The context setup process for a RPC server is to declare an exchange, then declare
  a queue to consume, and then bind the queue to the exchange. It also creates a
  default exchange to use it to respond to the reply-to queue.

  Every time a channel is open the context is set up, meaning that the queue and
  the exchange are declared and binded through the new channel based on the given
  configuration.

  The configuration must be a `Keyword.t` that contains the following keys:

    * `:exchange` - the exchange configuration expected by `Hare.Context.Action.DeclareExchange`
    * `:queue` - the queue configuration expected by `Hare.Context.Action.DeclareQueue`
    * `:bind` - (defaults to `[]`) binding options
  """

  @type payload :: Hare.Adapter.payload
  @type meta    :: map
  @type state   :: term

  @doc """
  Called when the RPC server process is first started. `start_link/5` will block
  until it returns.

  It receives as argument the fourth argument given to `start_link/5`.

  Returning `{:ok, state}` will cause `start_link/5` to return `{:ok, pid}`
  and attempt to open a channel on the given connection and declare the queue,
  the exchange, and the binding.
  After that it will enter the main loop with `state` as its internal state.

  Returning `:ignore` will cause `start_link/5` to return `:ignore` and the
  process will exit normally without entering the loop, opening a channel or calling
  `terminate/2`.

  Returning `{:stop, reason}` will cause `start_link/5` to return `{:error, reason}` and
  the process will exit with reason `reason` without entering the loop, opening a channel,
  or calling `terminate/2`.
  """
  @callback init(initial :: term) ::
              GenServer.on_start

  @doc """
  Called when the RPC server process has opened AMQP channel before registering
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
  Called when the AMQP server has registered the process as a RPC server and it
  will start to receive requests.

  Returning `{:noreply, state}` will causes the process to enter the main loop
  with the given state.

  Returning `{:stop, reason, state}` will terminate the main loop and call
  `terminate(reason, state)` before the process exits with reason `reason`.
  """
  @callback handle_ready(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when the AMQP server has been disconnected from the AMQP broker.

  Returning `{:noreply, state}` causes the process to enter the main loop with
  the given state. The server will not consume any new messages until connection
  to AMQP broker is established again.

  Returning `{:stop, reason, state}` will terminate the main loop and call
  `terminate(reason, state)` before the process exits with reason `reason`.
  """
  @callback handle_disconnected(reason :: term, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when a request is received from the queue.

  The arguments are the message's payload, some metadata and the internal state.
  The metadata is a map containing all metadata given by the adapter when receiving
  the message plus the `:exchange` and `:queue` values received at the `connect/2`
  callback.

  Returning `{:reply, response, state}` will respond inmediately to the client
  and enter the main loop with the given state.

  Returning `{:noreply, state}` will enter the main loop with the given state
  without responding. Therefore, `Hare.RPC.Server.reply/2` should be used to
  respond to the client.

  Returning `{:stop, reason, state}` will terminate the main loop and call
  `terminate(reason, state)` before the process exits with reason `reason`.
  """
  @callback handle_request(payload, meta, state) ::
              {:noreply, state} |
              {:reply, response :: binary, state} |
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
      @behaviour Hare.RPC.Server

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
      def handle_request(_payload, _meta, state),
        do: {:noreply, state}

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
                      handle_request: 3,
                      handle_call: 3, handle_cast: 2, handle_info: 2]
    end
  end

  use Hare.Actor

  alias __MODULE__.{Declaration, State}
  alias Hare.Core.{Queue, Exchange}

  @context Hare.Context

  @type config :: [queue:    Hare.Context.Action.DeclareQueue.config,
                   exchange: Hare.Context.Action.DeclareExchange.config,
                   bind:     Keyword.t]

  @doc """
  Starts a `Hare.RPC.Server` process linked to the current process.

  This function is used to start a `Hare.Consumer` process in a supervision
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

  @doc "Responds a request given its meta or replies to a call/2 caller"
  @spec reply(meta, response :: binary) :: :ok
  def reply(meta, response) when is_map(meta) do
    %{exchange:       exchange,
      reply_to:       target,
      correlation_id: correlation_id} = meta

    opts = [correlation_id: correlation_id]
    Exchange.publish(exchange, response, target, opts)
  end
  def reply(from, message) do
    Hare.Actor.reply(from, message)
  end

  defdelegate call(server, message),          to: Hare.Actor
  defdelegate call(server, message, timeout), to: Hare.Actor
  defdelegate cast(server, message),          to: Hare.Actor

  @doc false
  def init({config, context, mod, initial}) do
    with {:ok, declaration} <- build_declaration(config, context),
         {:ok, given}       <- mod_init(mod, initial) do
      {:ok, State.new(config, declaration, mod, given)}
    end
  end

  defp build_declaration(config, context) do
    with {:error, reason} <- Declaration.parse(config, context) do
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
    with {:noreply, new_given}  <- mod.handle_connected(given),
         new_state              <- State.set(state, new_given),
         {:ok, queue, exchange} <- Declaration.run(declaration, chan),
         {:ok, new_queue}       <- Queue.consume(queue, no_ack: true) do
      {:ok, State.connected(new_state, new_queue, exchange)}
    else
      {:stop, reason, new_given} -> {:stop, reason, State.set(state, new_given)}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  @doc false
  def disconnected(reason, %{mod: mod, given: given} = state) do
    new_state = State.disconnected(state)

    case mod.handle_disconnected(reason, given) do
      {:noreply, new_given} ->
        {:ok, State.set(new_state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(new_state, new_given)}
    end
  end

  @doc false
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
  def handle_info(message, %{queue: queue} = state) do
    case Queue.handle(queue, message) do
      {:consume_ok, meta} ->
        handle_mod_ready(meta, state)

      {:deliver, payload, meta} ->
        handle_mod_message(payload, meta, state)

      {:cancel_ok, _meta} ->
        {:stop, {:shutdown, :cancelled}, state}

      {:cancel, _meta} ->
        {:stop, :cancelled, state}

      :unknown ->
        handle_async(message, :handle_info, state)
    end
  end
  def handle_info(message, state) do
    handle_async(message, :handle_info, state)
  end

  @doc false
  def terminate(reason, %{mod: mod, given: given}),
    do: mod.terminate(reason, given)

  defp handle_mod_ready(meta, %{mod: mod, given: given} = state) do
    case mod.handle_ready(complete(meta, state), given) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  defp handle_mod_message(payload, meta, %{mod: mod, given: given} = state) do
    completed_meta = complete(meta, state)

    case mod.handle_request(payload, completed_meta, given) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:reply, response, new_given} ->
        reply(completed_meta, response)
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  defp complete(meta, %{queue: queue, exchange: exchange}),
    do: meta |> Map.put(:exchange, exchange) |> Map.put(:queue, queue)

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
end
