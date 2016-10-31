defmodule Hare.QueueTest do
  use ExUnit.Case, async: true

  alias Hare.{Queue, Chan}
  alias Hare.Adapter.Sandbox, as: Adapter

  test "get/2" do
    messages = ["foo"]

    {:ok, history}  = Adapter.Backdoor.start_history
    {:ok, messages} = Adapter.Backdoor.messages(messages)
    config = [history: history, messages: messages]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)

    channel = Chan.new(given_chan, Adapter)
    name    = "baz"

    queue = Queue.new(channel, name)

    assert {:ok, "foo", meta} = Queue.get(queue, no_ack: true)
    assert {:empty, %{}} = Queue.get(queue)

    assert :ok = Queue.ack(queue, meta)
    assert :ok = Queue.nack(queue, meta, multiple: true)
    assert :ok = Queue.reject(queue, meta)

    events = Adapter.Backdoor.events(history)

    assert [{:reject, [^given_chan, ^meta, []],               :ok},
            {:nack,   [^given_chan, ^meta, [multiple: true]], :ok},
            {:ack,    [^given_chan, ^meta, []],               :ok},
            {:get,    [^given_chan, "baz", []],               {:empty,%{}}},
            {:get,    [^given_chan, "baz", [no_ack: true]],   {:ok, "foo", ^meta}} | _] = Enum.reverse(events)
  end

  test "consume and cancel" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)

    channel = Chan.new(given_chan, Adapter)
    name    = "foo"

    queue = Queue.new(channel, name)

    assert {:ok, queue} = Queue.consume(queue, no_ack: true)
    assert %{consuming: true, consuming_pid: self, consumer_tag: tag} = queue

    args = [given_chan, "foo", self, [no_ack: true]]
    assert {:consume, args, {:ok, tag}} == Adapter.Backdoor.last_event(history)

    assert {:error, :already_consuming} = Queue.consume(queue)

    assert {:ok, queue} = Queue.cancel(queue, [no_wait: true])
    assert %{consuming: false, consuming_pid: nil, consumer_tag: nil} = queue

    args = [given_chan, tag, [no_wait: true]]
    assert {:cancel, args, :ok} == Adapter.Backdoor.last_event(history)

    pid = spawn(fn -> :ok end)
    assert {:ok, _queue} = Queue.consume(queue, pid)

    args = [given_chan, "foo", pid, []]
    assert {:consume, ^args, {:ok, _new_tag}} = Adapter.Backdoor.last_event(history)
  end
end
