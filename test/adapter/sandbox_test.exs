defmodule Hare.Adapter.SandboxTest do
  use ExUnit.Case, async: true

  alias Hare.Adapter.Sandbox, as: Adapter

  test "connect/1 and disconnect/1 with history and on_connect" do
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

    ref         = Adapter.monitor_connection(conn_1)
    assert true = Adapter.link_connection(conn_1)

    assert :ok = Adapter.close_connection(conn_1)
    assert_receive {:DOWN, ^ref, :process, _pid, :normal}

    assert {:error, :three} = Adapter.open_connection(config)
    assert {:ok, conn_2}    = Adapter.open_connection(config)

    expected_events = [{:open_connection,    [config], {:ok, conn_1}},
                       {:monitor_connection, [conn_1], ref},
                       {:link_connection,    [conn_1], true},
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
end
