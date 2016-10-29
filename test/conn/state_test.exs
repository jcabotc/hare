defmodule Hare.Conn.StateTest do
  use ExUnit.Case, async: true

  alias Hare.Conn.State
  alias Hare.Adapter.Sandbox, as: Adapter

  test "connection lifecycle" do
    steps = [{:error, :one},
             {:error, :two},
             {:error, :three},
             :ok,
             {:error, :four},
             :ok]

    {:ok, history}    = Adapter.Backdoor.start_history
    {:ok, on_connect} = Adapter.Backdoor.on_connect(steps)
    adapter_config = [history: history, on_connect: on_connect]

    state = State.new(adapter: Adapter,
                      backoff: [100, 1000],
                      config:  adapter_config)

    assert {:backoff, 100,  :one,   state} = State.connect(state)
    assert {:backoff, 1000, :two,   state} = State.connect(state)
    assert {:backoff, 1000, :three, state} = State.connect(state)
    assert %{status: :reconnecting} = state

    assert {:ok, state} = State.connect(state)
    assert %{status: :connected, conn: conn_1, ref: ref_1} = state

    Adapter.Backdoor.unlink(state.conn)
    Adapter.Backdoor.crash(state.conn, :simulated_crash)
    assert_receive {:DOWN, ^ref_1, :process, _pid, :simulated_crash}

    assert {:backoff, 100, :four, state} = State.connect(state)

    assert {:ok, state} = State.connect(state)
    assert %{status: :connected, conn: conn_2, ref: ref_2} = state

    assert %{status: :not_connected} = State.disconnect(state)

    expected_events = [{:open_connection,    [adapter_config], {:ok, conn_1}},
                       {:monitor_connection, [conn_1],         ref_1},
                       {:open_connection,    [adapter_config], {:ok, conn_2}},
                       {:monitor_connection, [conn_2],         ref_2},
                       {:close_connection,   [conn_2],         :ok}]

    assert expected_events == Adapter.Backdoor.events(history)
  end
end
