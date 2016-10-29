defmodule Hare.Conn do
  use Connection

  alias __MODULE__.{Bridge, Waiting}
  alias Hare.Channel

  def start_link(config, opts \\ []),
    do: Connection.start_link(__MODULE__, config, opts)

  def open_channel(conn),
    do: Connection.call(conn, :open_channel)

  def stop(conn, reason \\ :normal),
    do: Connection.call(conn, {:close, reason})

  def init(config) do
    state = %{bridge: Bridge.new(config), waiting: Waiting.new}
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

  def handle_call(:open_channel, from, state) do
    case try_open_channel(state, from) do
      {:wait, new_state} -> {:noreply, new_state}
      result             -> {:reply, result, state}
    end
  end
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

  defp handle_connection_try({:ok, new_bridge}, %{waiting: waiting} = state) do
    {froms, new_waiting} = Waiting.pop_all(waiting)
    reply_waiting(froms, new_bridge)

    {:ok, %{state | bridge: new_bridge, waiting: new_waiting}}
  end
  defp handle_connection_try({:retry, interval, _reason, new_bridge}, state) do
    {:retry, interval, %{state | bridge: new_bridge}}
  end

  defp reply_waiting(froms, bridge) do
    Enum.each froms, fn from ->
      result = Bridge.open_channel(bridge)

      Connection.reply(from, result)
    end
  end

  defp try_open_channel(%{bridge: bridge} = state, from),
    do: Bridge.open_channel(bridge) |> handle_open_channel_try(state, from)

  defp handle_open_channel_try({:ok, given_chan}, %{bridge: bridge}, _from),
    do: {:ok, Channel.new(given_chan, bridge.adapter)}
  defp handle_open_channel_try(:not_connected, %{waiting: waiting} = state, from),
    do: {:wait, %{state | waiting: Waiting.push(waiting, from)}}
  defp handle_open_channel_try({:error, _reason} = error, _state, _from),
    do: error
end
