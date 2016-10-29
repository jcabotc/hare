defmodule Hare.Conn do
  use Connection

  alias __MODULE__.Bridge

  def start_link(config, opts \\ []),
    do: Connection.start_link(__MODULE__, config, opts)

  def stop(conn, reason \\ :normal),
    do: Connection.call(conn, {:close, reason})

  def init(config) do
    state = %{bridge: Bridge.new(config)}

    {:connect, :init, state}
  end

  def connect(_info, %{bridge: bridge} = state) do
    case Bridge.connect(bridge) do
      {:ok, new_bridge} ->
        {:ok, %{state | bridge: new_bridge}}
      {:backoff, interval, _reason, new_bridge} ->
        {:backoff, interval, %{state | bridge: new_bridge}}
    end
  end

  def disconnect(reason, state),
    do: {:stop, reason, state}

  def handle_call({:close, reason}, _from, state) do
    {:disconnect, reason, :ok, state}
  end

  def handle_info({:DOWN, ref, _, _, _reason}, %{bridge: %{ref: ref}} = state),
    do: {:connect, :reconnect, state}
  def handle_info(_anything, state),
    do: {:noreply, state}

  def terminate(_reason, %{bridge: bridge}),
    do: Bridge.disconnect(bridge)
end
