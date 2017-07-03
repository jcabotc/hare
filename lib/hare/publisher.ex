defmodule Hare.Publisher do
  @moduledoc """
  A behaviour module for implementing AMQP publisher processes.

  The `Hare.Publisher` module provides a way to create processes that hold,
  monitor, and restart a channel in case of failure, exports a function to publish
  messages to an exchange, and some callbacks to hook into the process lifecycle.

  An example `Hare.Publisher` process that only sends every other message:

  ```
  defmodule MyPublisher do
    use Hare.Publisher

    def start_link(conn, config, opts \\ []) do
      Hare.Publisher.start_link(__MODULE__, conn, config, :ok, opts)
    end

    def publish(publisher, payload, routing_key) do
      Hare.Publisher.publish(publisher, payload, routing_key)
    end

    def init(:ok) do
      {:ok, %{last_ignored: false}}
    end

    def before_publication(_payload, _routing_key, _opts, %{last_ignored: false}) do
      {:ignore, %{last_ignored: true}}
    end
    def before_publication(_payload, _routing_key, _opts, %{last_ignored: true}) do
      {:ok, %{last_ignored: false}}
    end
  end
  ```

  ## Channel handling

  When the `Hare.Publisher` starts with `start_link/5` it runs the `init/1` callback
  and responds with `{:ok, pid}` on success, like a GenServer.

  After starting the process it attempts to open a channel on the given connection.
  It monitors the channel, and in case of failure it tries to reopen again and again
  on the same connection.

  ## Context setup

  The context setup process for a publisher is to declare its exchange.

  Every time a channel is open the context is set up, meaning that the exchange
  is declared through the new channel based on the given configuration.

  The configuration must be a `Keyword.t` that may contain a single key: `:exchange`
  whose value is the configuration for the `Hare.Context.Action.DeclareExchange`.
  Check it for more detailed information. If the `:exchange` key is omited, the
  default exchange will be used.
  """

  @type message     :: term
  @type payload     :: Hare.Adapter.payload
  @type routing_key :: Hare.Adapter.routing_key
  @type opts        :: Hare.Adapter.opts
  @type meta        :: map
  @type state       :: term

  @doc """
  Called when the publisher process is first started. `start_link/5` will block
  until it returns.

  It receives as argument the fourth argument given to `start_link/5`.

  Returning `{:ok, state}` will cause `start_link/5` to return `{:ok, pid}`
  and attempt to open a channel on the given connection and declare the exchange.
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
  Called when the publisher process has successfully opened AMQP channel.

  Returning `{:noreply, state}` will cause the process to enter the main loop
  with the given state.

  Returning `{:stop, reason, state}` will terminate the main loop and call
  `terminate(reason, state)` before the process exits with reason `reason`.
  """
  @callback handle_connected(state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when the AMQP publisher has been disconnected from the AMQP broker.

  Returning `{:noreply, state}` causes the process to enter the main loop with
  the given state. The publisher will not be able to send any new messages until
  connection to AMQP broker is established again.

  Returning `{:stop, reason, state}` will terminate the main loop and call
  `terminate(reason, state)` before the process exits with reason `reason`.
  """
  @callback handle_disconnected(reason :: term, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @doc """
  Called before a message will be published to the exchange.

  It receives as argument the message payload, the routing key, the options
  for that publication and the internal state.

  Returning `{:ok, state}` will cause the message to be sent with no
  modification, and enter the main loop with the given state.

  Returning `{:ok, payload, routing_key, opts, state}` will cause the
  given payload, routing key and options to be used instead of the original
  ones, and enter the main loop with the given state.

  Returning `{:ignore, state}` will ignore that message and enter the main loop
  again with the given state.

  Returning `{:stop, reason, state}` will not send the message, terminate the
  main loop and call `terminate(reason, state)` before the process exits with
  reason `reason`.
  """
  @callback before_publication(message, routing_key, opts :: term, state) ::
              {:ok, state} |
              {:ok, payload, routing_key, opts :: term, state} |
              {:ignore, state} |
              {:stop, reason :: term, state}

  @doc """
  Called after a message has been published to the exchange.

  It receives as argument the message payload, the routing key, the options
  for that publication and the internal state.

  Returning `{:ok, state}` will enter the main loop with the given state.

  Returning `{:stop, reason, state}` will terminate the
  main loop and call `terminate(reason, state)` before the process exits with
  reason `reason`.
  """
  @callback after_publication(payload, routing_key, opts :: term, state) ::
              {:ok, state} |
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
  @callback handle_info(message, state) ::
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
      @behaviour Hare.Publisher

      @doc false
      def init(initial),
        do: {:ok, initial}

      @doc false
      def handle_connected(state),
        do: {:noreply, state}

      @doc false
      def handle_disconnected(_reason, state),
        do: {:noreply, state}

      @doc false
      def before_publication(_payload, _routing_key, _meta, state),
        do: {:ok, state}

      @doc false
      def after_publication(_payload, _routing_key, _meta, state),
        do: {:ok, state}

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
                      handle_connected: 1, handle_disconnected: 2,
                      before_publication: 4, after_publication: 4,
                      handle_call: 3, handle_cast: 2, handle_info: 2]
    end
  end

  use Hare.Actor

  alias __MODULE__.{Declaration, State}
  alias Hare.Core.{Exchange}

  @context Hare.Context

  @type config        :: [config_option]
  @type config_option :: {:exchange, Hare.Context.Action.DeclareExchange.config}

  @doc """
  Starts a `Hare.Publisher` process linked to the current process.

  This function is used to start a `Hare.Publisher` process in a supervision
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

  defdelegate call(server, message),          to: Hare.Actor
  defdelegate call(server, message, timeout), to: Hare.Actor
  defdelegate cast(server, message),          to: Hare.Actor
  defdelegate reply(from, message),           to: Hare.Actor

  @doc """
  Publishes a message to an exchange through the `Hare.Publisher` process.
  """
  @spec publish(GenServer.server, payload :: term, routing_key, opts) :: :ok
  def publish(client, payload, routing_key \\ "", opts \\ []),
    do: Hare.Actor.cast(client, {:"$hare_publication", payload, routing_key, opts})

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
  def connected(chan, %{mod: mod, given: given, declaration: declaration} = state) do
    with {:noreply, new_given} <- mod.handle_connected(given),
         new_state             <- State.set(state, new_given),
         {:ok, exchange}       <- Declaration.run(declaration, chan) do
      {:ok, State.connected(new_state, exchange)}
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
  def handle_cast({:"$hare_publication", payload, key, opts}, %{mod: mod, given: given} = state) do
    case mod.before_publication(payload, key, opts, given) do
      {:ok, new_given} ->
        perform(payload, key, opts, new_given, state)

      {:ok, new_payload, new_routing_key, new_opts, new_given} ->
        perform(new_payload, new_routing_key, new_opts, new_given, state)

      {:ignore, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end
  def handle_cast(message, state),
    do: handle_async(message, :handle_cast, state)

  @doc false
  def handle_info(message, state),
    do: handle_async(message, :handle_info, state)

  @doc false
  def terminate(reason, %{mod: mod, given: given}),
    do: mod.terminate(reason, given)

  defp perform(_payload, _key, _opts, given, %{connected: false} = state) do
    {:noreply, State.set(state, given)}
  end
  defp perform(payload, key, opts, given, %{mod: mod, exchange: exchange} = state) do
    Exchange.publish(exchange, payload, key, opts)

    case mod.after_publication(payload, key, opts, given) do
      {:ok, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
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
end
