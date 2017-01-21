defmodule Hare.Consumer do
  @type payload :: binary
  @type meta    :: map
  @type state   :: term
  @type action  :: :ack | :nack | :reject

  @callback init(initial :: term) ::
              GenServer.on_start

  @callback connected(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @callback handle_ready(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @callback handle_message(payload, meta, state) ::
              {:reply, action, state} |
              {:reply, action, opts :: Keyword.t, state} |
              {:noreply, state} |
              {:stop, reason :: term, state}

  @callback handle_info(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @callback terminate(reason :: term, state) ::
              any

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      @behaviour Hare.Consumer

      def init(initial),
        do: {:ok, initial}

      def connected(_meta, state),
        do: {:noreply, state}

      def handle_ready(_meta, state),
        do: {:noreply, state}

      def handle_message(_payload, _meta, state),
        do: {:reply, :ack, state}

      def handle_info(_message, state),
        do: {:noreply, state}

      def terminate(_reason, _state),
        do: :ok

      defoverridable [init: 1, connected: 2, terminate: 2,
                      handle_ready: 2, handle_message: 3, handle_info: 2]
    end
  end

  use Connection

  alias __MODULE__.{Declaration, State}
  alias Hare.Core.{Chan, Queue}

  @context Hare.Context

  def start_link(mod, conn, config, initial, opts \\ []) do
    {context, opts} = Keyword.pop(opts, :context, @context)
    args = {mod, conn, config, context, initial}

    Connection.start_link(__MODULE__, args, opts)
  end

  def ack(%{queue: queue} = meta, opts \\ []),
    do: Queue.ack(queue, meta, opts)
  def nack(%{queue: queue} = meta, opts \\ []),
    do: Queue.nack(queue, meta, opts)
  def reject(%{queue: queue} = meta, opts \\ []),
    do: Queue.reject(queue, meta, opts)

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
    with {:ok, chan}            <- Chan.open(conn),
         {:ok, queue, exchange} <- Declaration.run(declaration, chan),
         {:ok, new_queue}       <- Queue.consume(queue) do
      handle_connected(state, chan, new_queue, exchange)
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  defp handle_connected(%{mod: mod, given: given} = state, chan, queue, exchange) do
    ref  = Chan.monitor(chan)
    meta = complete(%{}, state)

    case mod.connected(meta, given) do
      {:noreply, new_given} ->
        {:ok, State.connected(state, chan, ref, queue, exchange, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.connected(state, chan, ref, queue, exchange, new_given)}
    end
  end

  def disconnect(_info, state),
    do: {:stop, :normal, state}

  def handle_info({:DOWN, ref, _, _, _reason}, %{status: :connected, ref: ref} = state) do
    {:connect, :down, State.chan_down(state)}
  end
  def handle_info(message, %{status: :connected, queue: queue} = state) do
    case Queue.handle(queue, message) do
      {:consume_ok, meta} ->
        handle_mod_ready(meta, state)

      {:deliver, payload, meta} ->
        handle_mod_message(payload, meta, state)

      {:cancel_ok, _meta} ->
        {:stop, :cancelled, state}

      :unknown ->
        handle_mod_info(message, state)
    end
  end
  def handle_info(message, state) do
    handle_mod_info(message, state)
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

    case mod.handle_message(payload, completed_meta, given) do
      {:reply, :ack, new_given} ->
        ack(completed_meta)
        {:noreply, State.set(state, new_given)}

      {:reply, :nack, new_given} ->
        nack(completed_meta)
        {:noreply, State.set(state, new_given)}

      {:reply, :reject, new_given} ->
        reject(completed_meta)
        {:noreply, State.set(state, new_given)}

      {:reply, :ack, opts, new_given} ->
        ack(completed_meta, opts)
        {:noreply, State.set(state, new_given)}

      {:reply, :nack, opts, new_given} ->
        nack(completed_meta, opts)
        {:noreply, State.set(state, new_given)}

      {:reply, :reject, opts, new_given} ->
        reject(completed_meta, opts)
        {:noreply, State.set(state, new_given)}

      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
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

  defp complete(meta, %{queue: queue, exchange: exchange}),
    do: meta |> Map.put(:exchange, exchange) |> Map.put(:queue, queue)
end
