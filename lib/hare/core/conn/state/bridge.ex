defmodule Hare.Core.Conn.State.Bridge do
  alias __MODULE__

  defstruct [:adapter, :config,
             :backoff, :next_intervals,
             :given, :ref, :status]

  def new(config) do
    adapter      = Keyword.fetch!(config, :adapter)
    backoff      = Keyword.fetch!(config, :backoff)
    given_config = Keyword.fetch!(config, :config)

    %Bridge{adapter: adapter, backoff: backoff, config: given_config}
    |> set_not_connected
  end

  def connect(%Bridge{adapter: adapter, config: config} = bridge) do
    config
    |> adapter.open_connection
    |> handle_connect(bridge)
  end

  def open_channel(%Bridge{adapter: adapter, given: given, status: :connected}),
    do: adapter.open_channel(given)
  def open_channel(%Bridge{}),
    do: :not_connected

  def disconnect(%Bridge{adapter: adapter, given: given, status: :connected} = bridge) do
    adapter.close_connection(given)
    set_not_connected(bridge)
  end
  def disconnect(%Bridge{} = bridge) do
    set_not_connected(bridge)
  end

  defp handle_connect({:ok, given}, %{adapter: adapter} = bridge) do
    ref = adapter.monitor_connection(given)
    {:ok, set_connected(bridge, given, ref)}
  end
  defp handle_connect({:error, reason}, %{status: :reconnecting} = bridge) do
    {interval, new_state} = pop_interval(bridge)
    {:retry, interval, reason, new_state}
  end
  defp handle_connect(error, bridge) do
    handle_connect(error, set_reconnecting(bridge))
  end

  defp pop_interval(%{next_intervals: [last]} = bridge),
    do: {last, bridge}
  defp pop_interval(%{next_intervals: [next | rest]} = bridge),
    do: {next, %{bridge | next_intervals: rest}}

  defp set_connected(bridge, given, ref),
    do: %{bridge | status: :connected, given: given, ref: ref}
  defp set_reconnecting(%{backoff: backoff} = bridge),
    do: %{bridge | status: :reconnecting, given: nil, ref: nil, next_intervals: backoff}
  defp set_not_connected(bridge),
    do: %{bridge | status: :not_connected, given: nil, ref: nil}
end
