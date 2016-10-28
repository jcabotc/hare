defmodule Hare.Adapter.SandboxTest do
  use ExUnit.Case, async: true

  alias Hare.Adapter.Sandbox, as: Adapter
  alias Hare.Adapter.Sandbox.Backdoor

  test "connect/1 and disconnect/1 with history and on_connect" do
    {:ok, history}    = Backdoor.start_history
    {:ok, on_connect} = Backdoor.on_connect([{:error, :one}, {:error, :two}, :ok])

    config = [history:    history,
              on_connect: on_connect]

    assert {:error, :one} = Adapter.open_connection(config)
    assert {:error, :two} = Adapter.open_connection(config)
    assert {:ok, conn}    = Adapter.open_connection(config)

    ref         = Adapter.monitor_connection(conn)
    assert true = Adapter.link_connection(conn)

    assert :ok = Adapter.close_connection(conn)

    expected_events = [{:open_connection,    [config], {:ok, conn}},
                       {:monitor_connection, [conn],   ref},
                       {:link_connection,    [conn],   true},
                       {:close_connection,   [conn],   :ok}]

    assert expected_events == Backdoor.events(history)
  end
end
