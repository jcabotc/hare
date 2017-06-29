defmodule Hare.Actor do
  @callback init(args :: term) ::
    {:ok, state :: term} |
    :ignore |
    {:stop, reason :: term}

  @callback connected(chan :: Hare.Core.Chan.t, state :: term) ::
    {:ok, new_state} |
    {:stop, reason :: term, new_state} when new_state: term

  @callback disconnected(reason :: term, state :: term) ::
    {:ok, new_state} |
    {:stop, reason :: term, new_state} when new_state: term

  @callback handle_call(request :: term, GenServer.from, state :: term) ::
    {:reply, reply, new_state} |
    {:reply, reply, new_state, timeout | :hibernate} |
    {:noreply, new_state} |
    {:noreply, new_state, timeout | :hibernate} |
    {:stop, reason, reply, new_state} |
    {:stop, reason, new_state} when reply: term, new_state: term, reason: term

  @callback handle_cast(request :: term, state :: term) ::
    {:noreply, new_state} |
    {:noreply, new_state, timeout | :hibernate} |
    {:stop, reason :: term, new_state} when new_state: term

  @callback handle_info(message :: :timeout | term, state :: term) ::
    {:noreply, new_state} |
    {:noreply, new_state, timeout | :hibernate} |
    {:stop, reason :: term, new_state} when new_state: term

  @callback terminate(reason, state :: term) ::
    any when reason: :normal | :shutdown | {:shutdown, term} | term

  @callback code_change(old_vsn, state :: term, extra :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term} when old_vsn: term | {:down, term}

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      @behaviour Hare.Actor

      @doc false
      def init(initial) do
        {:ok, initial}
      end

      @doc false
      def connected(chan, state) do
        {:ok, state}
      end

      @doc false
      def disconnected(_reason, state) do
        {:ok, state}
      end

      @doc false
      def handle_call(message, _from, state) do
        {:stop, {:bad_call, message}, state}
      end

      @doc false
      def handle_cast(message, state) do
        {:stop, {:bad_cast, message}, state}
      end

      @doc false
      def handle_info(message, state) do
        {:noreply, state}
      end

      @doc false
      def terminate(_reason, state) do
        :ok
      end

      @doc false
      def code_change(_old, state, _extra) do
        {:ok, state}
      end

      defoverridable [init: 1, connected: 2, disconnected: 2, terminate: 2,
                      handle_call: 3, handle_cast: 2, handle_info: 2,
                      code_change: 3]
    end
  end

  use Connection

  alias __MODULE__.State

  def start_link(mod, conn, initial, opts \\ []) do
    args = {conn, mod, initial}
    Connection.start_link(__MODULE__, args, opts)
  end

  defdelegate call(actor, message),          to: Connection
  defdelegate call(actor, message, timeout), to: Connection
  defdelegate cast(actor, message),          to: Connection
  defdelegate reply(from, message),          to: Connection

  @doc false
  def init({conn, mod, initial}) do
    case mod.init(initial) do
      {:ok, given} ->
        {:connect, :init, State.new(conn, mod, given)}

      :ignore ->
        :ignore

      {:stop, reason} ->
        {:stop, reason}
    end
  end

  @doc false
  def connect(:init, state) do
    with {:ok, connected} <- State.open_channel(state),
         {:noreply, new_state} <- handle_mod_connected(connected) do
      {:ok, new_state}
    else
      {:error, reason, new_state} -> {:stop, reason, new_state}
      other -> other
    end
  end
  def connect(_info, state) do
    {:ok, State.request_channel(state)}
  end

  @doc false
  def disconnect(_info, state) do
    {:stop, :normal, state}
  end

  @doc false
  def handle_call(message, from, %{mod: mod, given: given} = state) do
    case mod.handle_call(message, from, given) do
      {:reply, reply, new_given} ->
        {:reply, reply, State.set(state, new_given)}

      {:reply, reply, new_given, hibernate} ->
        {:reply, reply, State.set(state, new_given), hibernate}

      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:noreply, new_given, hibernate} ->
        {:noreply, State.set(state, new_given), hibernate}

      {:stop, reason, reply, new_given} ->
        {:stop, reason, reply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  @doc false
  def handle_cast(message, %{mod: mod, given: given} = state) do
    case mod.handle_cast(message, given) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:noreply, new_given, hibernate} ->
        {:noreply, State.set(state, new_given), hibernate}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  @doc false
  def handle_info({:DOWN, ref, _, _, reason}, %{ref: ref} = state) do
    handle_mod_disconnected(reason, State.crash(state))
  end
  def handle_info({ref, result}, %{wait_ref: ref} = state) do
    case State.handle_open_channel(result, state) do
      {:ok, new_state} -> handle_mod_connected(new_state)
      {:error, reason, new_state} -> handle_mod_disconnected(reason, new_state)
    end
  end
  def handle_info(message, %{mod: mod, given: given} = state) do
    case mod.handle_info(message, given) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:noreply, new_given, hibernate} ->
        {:noreply, State.set(state, new_given), hibernate}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  @doc false
  def terminate(reason, %{mod: mod, given: given} = state) do
    mod.terminate(reason, given)
    State.down(state)
  end

  defp handle_mod_connected(%{mod: mod, chan: chan, given: given} = state) do
    case mod.connected(chan, given) do
      {:ok, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  defp handle_mod_disconnected(reason, %{mod: mod, given: given} = state) do
    case mod.disconnected(reason, given) do
      {:ok, new_given} ->
        {:connect, :down, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end
end
