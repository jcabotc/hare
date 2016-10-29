defmodule Hare.ConnTest do
  use ExUnit.Case, async: true

  alias Hare.{Conn, Channel}
  alias Hare.Adapter.Sandbox, as: Adapter

  test "opening channels" do
    chan_steps = [:ok, {:error, :chan_one}, :ok]

    {:ok, history}         = Adapter.Backdoor.start_history
    {:ok, on_channel_open} = Adapter.Backdoor.on_channel_open(chan_steps)
    adapter_config = [history: history, on_channel_open: on_channel_open]

    {:ok, pid} = Conn.start_link(adapter: Adapter,
                                 backoff: [100],
                                 config: adapter_config)

    assert {:ok, channel}      = Conn.open_channel(pid)
    assert {:error, :chan_one} = Conn.open_channel(pid)

    assert %Channel{given: given_chan, adapter: Adapter} = channel

    events = Adapter.Backdoor.events(history)

    assert [{:open_connection, [^adapter_config], {:ok, conn}},
            {:monitor_connection, [conn], _ref},
            {:open_channel, [conn], {:ok, ^given_chan}},
            {:open_channel, [conn], {:error, :chan_one}}] = events
  end
end
