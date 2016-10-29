defmodule Hare.ChannelTest do
  use ExUnit.Case, async: true

  alias Hare.Channel
  alias Hare.Adapter.Sandbox, as: Adapter

  test "monitor/1, link/1, unlink/1 and close/1" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)

    channel = Channel.new(given_chan, Adapter)

    ref = Channel.monitor(channel)
    assert true = Channel.link(channel)
    assert true = Channel.unlink(channel)
    assert :ok = Channel.close(channel)

    expected_events = [{:open_connection, [config],     {:ok, given_conn}},
                       {:open_channel,    [given_conn], {:ok, given_chan}},
                       {:monitor_channel, [given_chan], ref},
                       {:link_channel,    [given_chan], true},
                       {:unlink_channel,  [given_chan], true},
                       {:close_channel,   [given_chan], :ok}]

    assert expected_events == Adapter.Backdoor.events(history)
  end
end
