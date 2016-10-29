defmodule Hare.ConnTest do
  use ExUnit.Case, async: true

  alias Hare.{Conn, Channel}
  alias Hare.Adapter.Sandbox, as: Adapter

  test "opening channels" do
    steps = [{:error, :chan_one}, :ok]

    {:ok, history}         = Adapter.Backdoor.start_history
    {:ok, on_channel_open} = Adapter.Backdoor.on_channel_open(steps)
    adapter_config = [history: history, on_channel_open: on_channel_open]

    {:ok, pid} = Conn.start_link(adapter: Adapter,
                                 backoff: [0],
                                 config: adapter_config)

    assert {:error, :chan_one} = Conn.open_channel(pid)

    assert {:ok, channel} = Conn.open_channel(pid)
    assert %Channel{given: given_chan, adapter: Adapter} = channel

    assert :ok = Conn.stop(pid)

    events = Adapter.Backdoor.events(history)

    assert [{:open_connection, [^adapter_config], {:ok, conn}},
            {:monitor_connection, [conn], _ref},
            {:open_channel, [conn], {:error, :chan_one}},
            {:open_channel, [conn], {:ok, ^given_chan}},
            {:close_connection, [conn], :ok}] = events
  end

  test "on connection crash" do
    steps = [{:error, :one}, {:error, :two}, :ok]

    {:ok, history}    = Adapter.Backdoor.start_history
    {:ok, on_connect} = Adapter.Backdoor.on_connect(steps)
    adapter_config = [history: history, on_connect: on_connect]

    {:ok, pid} = Conn.start_link(adapter: Adapter,
                                 backoff: [100],
                                 config:  adapter_config)

    task_1 = Task.async fn -> Conn.open_channel(pid) end
    task_2 = Task.async fn -> Conn.open_channel(pid) end
    Process.sleep(5)

    assert nil == Task.yield(task_1, 0)
    assert nil == Task.yield(task_2, 0)

    {:ok, _channel} = Task.await(task_1)
    {:ok, _channel} = Task.await(task_2)
  end
end
