defmodule Hare.Adapter.SandboxTest do
  use ExUnit.Case, async: true

  alias Hare.Adapter.Sandbox, as: Adapter

  test "connect, monitor and disconnect with history and on_connect" do
    steps = [{:error, :one},
             {:error, :two},
             :ok,
             {:error, :three},
             :ok]

    {:ok, history}    = Adapter.Backdoor.start_history
    {:ok, on_connect} = Adapter.Backdoor.on_connect(steps)

    config = [history:    history,
              on_connect: on_connect]

    assert {:error, :one} = Adapter.open_connection(config)
    assert {:error, :two} = Adapter.open_connection(config)
    assert {:ok, conn_1}  = Adapter.open_connection(config)

    ref = Adapter.monitor_connection(conn_1)

    assert :ok = Adapter.close_connection(conn_1)
    assert_receive {:DOWN, ^ref, :process, _pid, :normal}

    assert {:error, :three} = Adapter.open_connection(config)
    assert {:ok, conn_2}    = Adapter.open_connection(config)

    expected_events = [{:open_connection,    [config], {:ok, conn_1}},
                       {:monitor_connection, [conn_1], ref},
                       {:close_connection,   [conn_1], :ok},
                       {:open_connection,    [config], {:ok, conn_2}}]

    assert expected_events == Adapter.Backdoor.events(history)
  end

  test "crash connection" do
    {:ok, conn} = Adapter.open_connection([])
    ref         = Adapter.monitor_connection(conn)

    Adapter.Backdoor.unlink(conn)
    Adapter.Backdoor.crash(conn, :simulated)
    assert_receive {:DOWN, ^ref, _, _, :simulated}
  end

  test "channel open, monitor, close with on_channel_open" do
    Process.flag(:trap_exit, true)

    steps = [{:error, :one}, :ok,
             {:error, :two}, :ok]

    {:ok, history}         = Adapter.Backdoor.start_history
    {:ok, on_channel_open} = Adapter.Backdoor.on_channel_open(steps)

    config = [history: history, on_channel_open: on_channel_open]
    {:ok, conn} = Adapter.open_connection(config)

    assert {:error, :one} = Adapter.open_channel(conn)
    assert {:ok, chan_1}  = Adapter.open_channel(conn)

    ref = Adapter.monitor_channel(chan_1)
    assert true ==  Adapter.link_channel(chan_1)

    assert :ok = Adapter.close_channel(chan_1)
    assert_receive {:DOWN, ^ref, _, _, :normal}
    assert_receive {:EXIT, _from, :normal}

    assert {:error, :two} = Adapter.open_channel(conn)
    assert {:ok, chan_2}  = Adapter.open_channel(conn)

    expected_events = [{:open_connection, [config], {:ok, conn}},
                       {:open_channel,    [conn],   {:error, :one}},
                       {:open_channel,    [conn],   {:ok, chan_1}},
                       {:monitor_channel, [chan_1], ref},
                       {:link_channel,    [chan_1], true},
                       {:close_channel,   [chan_1], :ok},
                       {:open_channel,    [conn],   {:error, :two}},
                       {:open_channel,    [conn],   {:ok, chan_2}}]

    assert expected_events == Adapter.Backdoor.events(history)
  end

  test "channel on crash and on connection crash" do
    Process.flag(:trap_exit, true)
    {:ok, conn} = Adapter.open_connection([])

    assert {:ok, chan}  = Adapter.open_channel(conn)

    ref = Adapter.monitor_channel(chan)
    assert true ==  Adapter.link_channel(chan)

    Adapter.Backdoor.crash(chan, :simulated_crash)
    assert_receive {:DOWN, ^ref, _, _, :simulated_crash}
    assert_receive {:EXIT, _from, :simulated_crash}

    assert {:ok, chan}  = Adapter.open_channel(conn)

    ref = Adapter.monitor_channel(chan)
    assert true ==  Adapter.link_channel(chan)
    assert true ==  Adapter.unlink_channel(chan)

    Adapter.Backdoor.unlink(conn)
    Adapter.Backdoor.crash(conn, :simulated_crash)
    assert_receive {:DOWN, ^ref, _, _, {:connection_down, :simulated_crash}}
    refute_receive {:EXIT, _from, {:connection_down, :simulated_crash}}, 10
  end
end
