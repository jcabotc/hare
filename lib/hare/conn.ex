defmodule Hare.Conn do
  use Connection

  alias __MODULE__.{Bridge, Waiting}

  def start_link(config, opts \\ []),
    do: Connection.start_link(__MODULE__, config, opts)

  def stop(conn, reason \\ :normal),
    do: Connection.call(conn, {:close, reason})

  def init(config) do
    state = %{bridge:  Bridge.new(config),
              waiting: Waiting.new}

    {:connect, :init, state}
  end

  def connect(_info, state) do
    case try_connect(state) do
      {:ok, new_state}              -> {:ok, new_state}
      {:retry, interval, new_state} -> {:backoff, interval, new_state}
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

  defp try_connect(%{bridge: bridge} = state),
    do: Bridge.connect(bridge) |> handle_connection_try(state)

  defp handle_connection_try({:ok, new_bridge}, state) do
    {:ok, %{state | bridge: new_bridge}}
  end
  defp handle_connection_try({:retry, interval, _reason, new_bridge}, state) do
    {:retry, interval, %{state | bridge: new_bridge}}
  end
end
