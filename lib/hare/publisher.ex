defmodule Hare.Publisher do
  @type payload     :: binary
  @type routing_key :: binary
  @type meta        :: map
  @type state       :: term

  @callback init(initial :: term) ::
              GenServer.on_start

  @callback connected(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @callback handle_publication(payload, routing_key, opts :: term, state) ::
              {:ok, state} |
              {:ok, payload, routing_key, opts :: term, state} |
              {:ignore, state} |
              {:stop, reason :: term, state}

  @callback handle_info(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @callback terminate(reason :: term, state) ::
              any

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      @behaviour Hare.Publisher

      def init(initial),
        do: {:ok, initial}

      def connected(_meta, state),
        do: {:noreply, state}

      def handle_publication(_payload, _routing_key, _meta, state),
        do: {:ok, state}

      def handle_info(_message, state),
        do: {:noreply, state}

      def terminate(_reason, _state),
        do: :ok

      defoverridable [init: 1, terminate: 2, connected: 2,
                      handle_publication: 4, handle_info: 2]
    end
  end

  use Connection

  alias __MODULE__.{Declaration, State}
  alias Hare.Core.{Chan, Exchange}

  @context Hare.Context

  def start_link(mod, conn, config, initial, opts \\ []) do
    {context, opts} = Keyword.pop(opts, :context, @context)
    args = {mod, conn, config, context,  initial}

    Connection.start_link(__MODULE__, args, opts)
  end

  def publish(client, payload, routing_key \\ "", opts \\ []),
    do: Connection.cast(client, {:publication, payload, routing_key, opts})

  def init({mod, conn, config, context, initial}) do
    with {:ok, declaration} <- Declaration.parse(config, context),
         {:ok, given}       <- mod.init(initial) do
      {:connect, :init, State.new(conn, declaration, mod, given)}
    else
      {:error, reason} -> {:stop, {:config_error, reason, config}}
      other            -> other
    end
  end

  def connect(_info, %{conn: conn, declaration: declaration} = state) do
    with {:ok, chan}     <- Chan.open(conn),
         {:ok, exchange} <- Declaration.run(declaration, chan) do
      handle_connected(state, chan, exchange)
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  defp handle_connected(%{mod: mod, given: given} = state, chan, exchange) do
    ref  = Chan.monitor(chan)
    meta = complete(%{}, state)

    case mod.connected(meta, given) do
      {:noreply, new_given} ->
        {:ok, State.connected(state, chan, ref, exchange, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.connected(state, chan, ref, exchange, new_given)}
    end
  end

  def disconnect(_info, state),
    do: {:stop, :normal, state}

  def handle_cast({:publication, payload, routing_key, opts}, %{mod: mod, given: given} = state) do
    case mod.handle_publication(payload, routing_key, opts, given) do
      {:ok, new_given} ->
        perform(payload, routing_key, opts, state)
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

  def handle_info({:DOWN, ref, _, _, _reason}, %{status: :connected, ref: ref} = state) do
    {:connect, :down, State.chan_down(state)}
  end
  def handle_info(message, %{mod: mod, given: given} = state) do
    case mod.handle_info(message, given) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  def terminate(reason, %{status: :connected, chan: chan} = state) do
    mod_terminate(reason, state)
    Chan.close(chan)
  end
  def terminate(reason, state) do
    mod_terminate(reason, state)
  end

  defp mod_terminate(reason, %{mod: mod, given: given}),
    do: mod.terminate(reason, given)

  defp perform(payload, routing_key, opts, %{exchange: exchange}),
    do: Exchange.publish(exchange, payload, routing_key, opts)

  defp complete(meta, %{exchange: exchange}),
    do: Map.put(meta, :exchange, exchange)
end
