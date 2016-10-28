defmodule Hare.Adapter.SandboxTest do
  use ExUnit.Case, async: true

  alias Hare.Adapter.Sandbox, as: Adapter
  alias Hare.Adapter.Sandbox.Backdoor

  test "connect/1 and disconnect/1 with history and on_connect" do
    {:ok, history} = Backdoor.start_history
    config = [history: history]

    assert {:ok, conn} = Adapter.open_connection(config)
    ref                = Adapter.monitor_connection(conn)
    assert true        = Adapter.link_connection(conn)
    assert :ok         = Adapter.close_connection(conn)

    expected_events = [{:open_connection,    [config], {:ok, conn}},
                       {:monitor_connection, [conn],   ref},
                       {:link_connection,    [conn],   true},
                       {:close_connection,   [conn],   :ok}]

    assert expected_events == Backdoor.events(history)
  end
end
