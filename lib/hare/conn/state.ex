defmodule Hare.Conn.State do
  alias __MODULE__

  defstruct [:adapter, :config,
             :backoff, :next_intervals,
             :conn, :ref, :status]

  def new(config) do
    adapter = Keyword.fetch!(config, :adapter)
    backoff = Keyword.fetch!(config, :backoff)
    config  = Keyword.fetch!(config, :config)

    %State{adapter: adapter, backoff: backoff, config: config}
    |> set_not_connected
  end

  def connect(%State{adapter: adapter, config: config} = state) do
    config
    |> adapter.open_connection
    |> handle_connect(state)
  end

  def open_channel(%State{adapter: adapter, conn: conn, status: :connected}),
    do: adapter.open_channel(conn)
  def open_channel(%State{status: status}),
    do: {:error, status}

  def disconnect(%State{adapter: adapter, conn: conn, status: :connected} = state) do
    adapter.close_connection(conn)
    set_not_connected(state)
  end
  def disconnect(%State{} = state) do
    set_not_connected(state)
  end

  defp handle_connect({:ok, conn}, %{adapter: adapter} = state) do
    ref = adapter.monitor_connection(conn)
    {:ok, set_connected(state, conn, ref)}
  end
  defp handle_connect({:error, reason}, %{status: :reconnecting} = state) do
    {interval, new_state} = pop_interval(state)
    {:backoff, interval, reason, new_state}
  end
  defp handle_connect(error, state) do
    handle_connect(error, set_reconnecting(state))
  end

  defp pop_interval(%{next_intervals: [last]} = state),
    do: {last, state}
  defp pop_interval(%{next_intervals: [next | rest]} = state),
    do: {next, %{state | next_intervals: rest}}

  defp set_connected(state, conn, ref),
    do: %{state | status: :connected, conn: conn, ref: ref}
  defp set_reconnecting(%{backoff: backoff} = state),
    do: %{state | status: :reconnecting, conn: nil, ref: nil, next_intervals: backoff}
  defp set_not_connected(state),
    do: %{state | status: :not_connected, conn: nil, ref: nil}
end
