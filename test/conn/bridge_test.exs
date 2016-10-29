defmodule Hare.Conn.BridgeTest do
  use ExUnit.Case, async: true

  alias Hare.Conn.Bridge
  alias Hare.Adapter.Sandbox, as: Adapter

  test "connection lifecycle" do
    steps = [{:error, :one}, {:error, :two}, {:error, :three}, :ok,
             {:error, :four}, :ok]

    {:ok, history}    = Adapter.Backdoor.start_history
    {:ok, on_connect} = Adapter.Backdoor.on_connect(steps)
    adapter_config = [history: history, on_connect: on_connect]

    bridge = Bridge.new(adapter: Adapter,
                        backoff: [100, 1000],
                        config:  adapter_config)

    assert {:retry, 100,  :one,   bridge} = Bridge.connect(bridge)
    assert {:retry, 1000, :two,   bridge} = Bridge.connect(bridge)
    assert {:retry, 1000, :three, bridge} = Bridge.connect(bridge)
    assert %{status: :reconnecting} = bridge

    assert {:error, :not_connected} = Bridge.open_channel(bridge)

    assert {:ok, bridge} = Bridge.connect(bridge)
    assert %{status: :connected, given: given_1, ref: ref_1} = bridge

    assert {:ok, given_chan} = Bridge.open_channel(bridge)

    Adapter.Backdoor.unlink(given_chan)
    Adapter.Backdoor.unlink(bridge.given)
    Adapter.Backdoor.crash(bridge.given, :simulated_crash)
    assert_receive {:DOWN, ^ref_1, :process, _pid, :simulated_crash}

    assert {:retry, 100, :four, bridge} = Bridge.connect(bridge)

    assert {:ok, bridge} = Bridge.connect(bridge)
    assert %{status: :connected, given: given_2, ref: ref_2} = bridge

    assert %{status: :not_connected} = Bridge.disconnect(bridge)

    expected_events = [{:open_connection,    [adapter_config], {:ok, given_1}},
                       {:monitor_connection, [given_1],         ref_1},
                       {:open_channel,       [given_1],         {:ok, given_chan}},
                       {:open_connection,    [adapter_config], {:ok, given_2}},
                       {:monitor_connection, [given_2],         ref_2},
                       {:close_connection,   [given_2],         :ok}]

    assert expected_events == Adapter.Backdoor.events(history)
  end
end
