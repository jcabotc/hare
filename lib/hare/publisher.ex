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

    def handle_publication(_payload, _routing_key, _opts, %{last_ignored: false}) do
      {:ignore, %{last_ignored: true}}
    end
    def handle_publication(_payload, _routing_key, _opts, %{last_ignored: true}) do
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
  main loop and call `terminate(reason, state)` before the process exists with
  reason `reason`.
  """
  @callback handle_publication(payload, routing_key, opts :: term, state) ::
              {:ok, state} |
              {:ok, payload, routing_key, opts :: term, state} |
              {:ignore, state} |
              {:stop, reason :: term, state}

  @doc """
  Called when the process receives a message.

  Returning `{:noreply, state}` will causes the process to enter the main loop
  with the given state.

  Returning `{:stop, reason, state}` will not send the message, terminate the
  main loop and call `terminate(reason, state)` before the process exists with
  reason `reason`.
  """
  @callback handle_info(message :: term, state) ::
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
      def handle_publication(_payload, _routing_key, _meta, state),
        do: {:ok, state}

      @doc false
      def handle_info(_message, state),
        do: {:noreply, state}

      @doc false
      def terminate(_reason, _state),
        do: :ok

      defoverridable [init: 1, terminate: 2,
                      handle_publication: 4, handle_info: 2]
    end
  end

  use Hare.Role.Layer

  alias __MODULE__.{Declaration, State}
  alias Hare.Core.{Exchange}

  @context Hare.Context

  @type config :: [exchange: Hare.Context.Action.DeclareExchange.config]

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
  @spec start_link(module, pid, config, initial :: term, GenServer.options) :: GenServer.on_start
  def start_link(mod, conn, config, initial, opts \\ []) do
    {context, opts} = Keyword.pop(opts, :context, @context)
    layers          = [__MODULE__]

    args = {mod, config, context, initial}
    Hare.Role.start_link(conn, layers, args, opts)
  end

  @doc """
  Publishes a message to an exchange through the `Hare.Publisher` process.
  """
  @spec publish(pid, payload, routing_key, opts) :: :ok
  def publish(client, payload, routing_key \\ "", opts \\ []),
    do: Hare.Role.cast(client, {:publication, payload, routing_key, opts})

  @doc false
  def init(_next, {mod, config, context, initial}) do
    with {:ok, declaration} <- build_declaration(config, context),
         {:ok, given}       <- mod_init(mod, initial) do
      {:ok, State.new(declaration, mod, given)}
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
  def declare(chan, _next, %{declaration: declaration} = state) do
    case Declaration.run(declaration, chan) do
      {:ok, exchange} ->
        {:ok, State.declared(state, exchange)}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  @doc false
  def handle_cast({:publication, payload, key, opts}, _next, %{mod: mod, given: given} = state) do
    case mod.handle_publication(payload, key, opts, given) do
      {:ok, new_given} ->
        perform(payload, key, opts, state)
        {:noreply, State.set(state, new_given)}

      {:ok, new_payload, new_routing_key, new_opts, new_given} ->
        perform(new_payload, new_routing_key, new_opts, state)
        {:noreply, State.set(state, new_given)}

      {:ignore, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  @doc false
  def handle_info(message, _next, %{mod: mod, given: given} = state) do
    case mod.handle_info(message, given) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  @doc false
  def terminate(reason, %{mod: mod, given: given}) do
    mod.terminate(reason, given)
  end

  defp perform(payload, routing_key, opts, %{exchange: exchange}),
    do: Exchange.publish(exchange, payload, routing_key, opts)
end
