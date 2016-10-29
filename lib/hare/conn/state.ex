defmodule Hare.Conn.State do
  alias __MODULE__
  alias __MODULE__.{Bridge, Waiting}
  alias Hare.Chan

  defstruct [:bridge, :waiting, :reply]

  def new(config, reply) do
    bridge  = Bridge.new(config)
    waiting = Waiting.new

    %State{bridge: bridge, waiting: waiting, reply: reply}
  end

  def connect(%State{bridge: bridge} = state),
    do: Bridge.connect(bridge) |> handle_connect(state)

  def down?(%State{bridge: bridge}, ref),
    do: bridge.ref == ref

  def open_channel(%State{bridge: bridge} = state, client),
    do: Bridge.open_channel(bridge) |> handle_open_channel(state, client)

  def disconnect(%State{bridge: bridge}),
    do: Bridge.disconnect(bridge)

  defp handle_connect({:ok, new_bridge}, %{waiting: waiting, reply: reply} = state) do
    {clients, new_waiting} = Waiting.pop_all(waiting)
    reply_waiting(clients, new_bridge, reply)

    {:ok, %{state | bridge: new_bridge, waiting: new_waiting}}
  end
  defp handle_connect({:retry, interval, _reason, new_bridge}, state) do
    {:retry, interval, %{state | bridge: new_bridge}}
  end

  defp handle_open_channel({:ok, given_chan}, %{bridge: bridge}, _client) do
    {:ok, Chan.new(given_chan, bridge.adapter)}
  end
  defp handle_open_channel(:not_connected, %{waiting: waiting} = state, client) do
    {:wait, %{state | waiting: Waiting.push(waiting, client)}}
  end
  defp handle_open_channel({:error, _reason} = error, _state, _client) do
    error
  end

  defp reply_waiting(clients, bridge, reply) do
    Enum.each(clients, fn client ->
      result = Bridge.open_channel(bridge)
      reply.(client, result)
    end)
  end
end
