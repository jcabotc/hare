defmodule Hare.Role do
  use Connection

  alias __MODULE__.State

  def start_link(conn, layers, initial, opts \\ []) do
    args = {conn, layers, initial}

    Connection.start_link(__MODULE__, args, opts)
  end

  def call(pid, message),
    do: GenServer.call(pid, message)
  def call(pid, message, timeout),
    do: GenServer.call(pid, message, timeout)

  def cast(pid, message),
    do: GenServer.cast(pid, message)

  def init({conn, layers, given}) do
    state = State.new(conn, layers, given)

    case run(state, :init, []) do
      {:ok, new_given} ->
        {:connect, :init, State.new(conn, layers, new_given)}

      :ignore ->
        :ignore

      {:stop, reason} ->
        {:stop, reason}

      :no_more_layers ->
        {:stop, {:no_more_layers, :init, [given]}}
    end
  end

  def connect(_info, %{conn: conn} = state) do
    case run(state, :channel, [conn]) do
      {:ok, chan, new_given} ->
        handle_channel_opened(state, chan, new_given)

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}

      :no_more_layers ->
        {:stop, {:no_more_layers, :channel, [conn, state.given]}, state}
    end
  end

  defp handle_channel_opened(state, chan, given) do
    case run(state, :declare, [chan]) do
      {:ok, new_given} ->
        {:ok, State.set(state, chan, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, chan, new_given)}

      :no_more_layers ->
        {:stop, {:no_more_layers, :declare, [chan, given]}, state}
    end
  end

  def disconnect(_info, state) do
    {:stop, :normal, state}
  end

  def handle_call(message, from, state) do
    case run(state, :handle_call, [message, from]) do
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

      :no_more_layers ->
        {:stop, {:no_more_layers, :handle_call, [message, from, state.given]}, state}
    end
  end

  def handle_cast(message, state) do
    handle_async(message, :handle_cast, state)
  end

  def handle_info({:DOWN, ref, _, _, _reason}, %{status: :up, ref: ref} = state),
    do: {:connect, :down, State.down(state)}
  def handle_info(message, state),
    do: handle_async(message, :handle_info, state)

  defp handle_async(message, fun, state) do
    case run(state, fun, [message]) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:noreply, new_given, hibernate} ->
        {:noreply, State.set(state, new_given), hibernate}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}

      :no_more_layers ->
        {:stop, {:no_more_layers, fun, [message, state.given]}, state}
    end
  end

  def terminate(reason, state) do
    run(state, :terminate, [reason])
    State.close(state)
  end

  defp run(%{layers: layers, given: given}, fun, args),
    do: do_run(layers, fun, args, given)

  defp do_run([], _fun, _args, _given) do
    :no_more_layers
  end
  defp do_run([layer | rest], fun, args, given) do
    next = &do_run(rest, fun, args, &1)

    apply(layer, fun, args ++ [next, given])
  end
end
