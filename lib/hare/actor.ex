defmodule Hare.Actor do
  @callback init(args :: term) ::
    {:ok, state :: term} |
    :ignore |
    {:stop, reason :: term}

  @callback declare(chan :: Hare.Core.Chan.t, state :: term) ::
    {:ok, new_state} |
    {:ok, new_state, timeout | :hibernate} |
    {:stop, reason :: term} when new_state: term

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
      def declare(chan, state) do
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

      defoverridable [init: 1, declare: 2, terminate: 2,
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

  def init({conn, mod, initial}) do
    Process.flag(:trap_exit, true)
    case mod.init(initial) do
      {:ok, given} ->
        {:connect, :init, State.new(conn, mod, given)}

      :ignore ->
        :ignore

      {:stop, reason} ->
        {:stop, reason}
    end
  end

  def connect(_info, state) do
    case State.up(state) do
      {:ok, new_state} ->
        declare(new_state)

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  defp declare(%{chan: chan, mod: mod, given: given} = state) do
    case mod.declare(chan, given) do
      {:ok, new_given} ->
        {:ok, State.set(state, new_given)}

      {:ok, new_given, timeout} ->
        {:ok, State.set(state, new_given), timeout}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  def disconnect(_info, state) do
    {:stop, :normal, state}
  end

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

  def handle_info({:DOWN, ref, _, _, _reason}, %{ref: ref} = state) do
    {:connect, :down, State.crash(state)}
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

  def terminate(reason, %{mod: mod, given: given} = state) do
    mod.terminate(reason, given)
    State.down(state)
  end
end
