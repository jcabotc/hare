defmodule Hare.Conn do
  use Connection

  alias __MODULE__.State

  def start_link(config, opts \\ []) do
    Connection.start_link(__MODULE__, config, opts)
  end

  def stop(conn, reason \\ :normal) do
    Connection.call(conn, {:close, reason})
  end

  def init(config) do
    state = State.new(config)

    {:connect, :init, state}
  end

  def connect(_info, state) do
    case State.connect(state) do
      {:ok, new_state} ->
        {:ok, new_state}
      {:backoff, interval, _reason, new_state} ->
        {:backoff, interval, new_state}
    end
  end

  def disconnect(reason, state) do
    {:stop, reason, state}
  end

  def handle_call({:close, reason}, _from, state) do
    {:disconnect, reason, :ok, state}
  end

  def handle_info({:DOWN, ref, _, _, _reason}, %{ref: ref} = state) do
    {:connect, :reconnect, state}
  end
  def handle_info(_anything, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    State.disconnect(state)
  end
end
