defmodule Hare.Core.ChanTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Chan
  alias Hare.Adapter.Sandbox, as: Adapter

  test "qos/2, monitor/1, link/1, unlink/1 and close/1" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)

    channel = Chan.new(given_chan, Adapter)

    ref = Chan.monitor(channel)
    assert true = Chan.link(channel)
    assert true = Chan.unlink(channel)

    assert :ok = Chan.qos(channel, prefetch_count: 10)
    assert :ok = Chan.close(channel)

    expected_events = [{:open_connection, [config],                           {:ok, given_conn}},
                       {:open_channel,    [given_conn],                       {:ok, given_chan}},
                       {:monitor_channel, [given_chan],                       ref},
                       {:link_channel,    [given_chan],                       true},
                       {:unlink_channel,  [given_chan],                       true},
                       {:qos,             [given_chan, [prefetch_count: 10]], :ok},
                       {:close_channel,   [given_chan],                       :ok}]

    assert expected_events == Adapter.Backdoor.events(history)
  end
end
