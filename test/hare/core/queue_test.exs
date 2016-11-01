defmodule Hare.Core.QueueTest do
  use ExUnit.Case, async: true

  alias Hare.Core.{Queue, Chan}
  alias Hare.Adapter.Sandbox, as: Adapter

  def build_channel(messages \\ []) do
    {:ok, history}  = Adapter.Backdoor.start_history
    {:ok, messages} = Adapter.Backdoor.messages(messages)
    config = [history: history, messages: messages]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)

    {history, Chan.new(given_chan, Adapter)}
  end

  test "declare/3, purge/1 and delete/1" do
    {history, chan} = build_channel

    assert {:ok, info, queue} = Queue.declare(chan, "foo", [durable: true])
    assert queue.chan == chan
    assert queue.name == "foo"
    assert {:declare_queue,
            [_given, "foo", [durable: true]],
            {:ok, ^info}} = Adapter.Backdoor.last_event(history)

    assert {:ok, info, ^queue} = Queue.declare(chan, "foo")
    assert {:declare_queue,
            [_given, "foo", []],
            {:ok, ^info}} = Adapter.Backdoor.last_event(history)

    assert :ok == Queue.delete(queue)
    assert {:delete_queue,
            [_given, "foo", []],
            :ok} = Adapter.Backdoor.last_event(history)
  end

  test "declare/1 and declare/2 with server named queue" do
    {history, chan} = build_channel

    assert {:ok, info, queue} = Queue.declare(chan)
    assert %{name: name} = queue
    assert {:declare_server_named_queue,
            [_given, []],
            {:ok, ^name, ^info}} = Adapter.Backdoor.last_event(history)

    assert {:ok, info, queue} = Queue.declare(chan, auto_delete: true)
    assert %{name: name} = queue
    assert {:declare_server_named_queue,
            [_given, [auto_delete: true]],
            {:ok, ^name, ^info}} = Adapter.Backdoor.last_event(history)
  end

  test "bind/3 and unbind/3" do
    {history, chan} = build_channel

    queue = Queue.new(chan, "foo")

    {:ok, ^queue, exchange} = Queue.bind(queue, "bar", routing_key: "key.*")
    assert {:bind,
            [_given, "foo", "bar", [routing_key: "key.*"]],
            :ok} = Adapter.Backdoor.last_event(history)

    {:ok, ^queue, ^exchange} = Queue.bind(queue, exchange)
    assert {:bind,
            [_given, "foo", "bar", []],
            :ok} = Adapter.Backdoor.last_event(history)

    {:ok, ^queue, ^exchange} = Queue.unbind(queue, "bar")
    assert {:unbind,
            [_given, "foo", "bar", []],
            :ok} = Adapter.Backdoor.last_event(history)

    {:ok, ^queue, ^exchange} = Queue.unbind(queue, exchange, no_wait: true)
    assert {:unbind,
            [_given, "foo", "bar", [no_wait: true]],
            :ok} = Adapter.Backdoor.last_event(history)
  end

  test "get/2, acks and purge/1" do
    messages = ["foo"]
    {history, chan} = build_channel(messages)

    queue = Queue.new(chan, "baz")

    assert {:ok, "foo", meta} = Queue.get(queue, no_ack: true)
    assert {:empty, %{}} = Queue.get(queue)

    assert :ok = Queue.ack(queue, meta)
    assert :ok = Queue.nack(queue, meta, multiple: true)
    assert :ok = Queue.reject(queue, meta)

    assert {:ok, %{}} = Queue.purge(queue)

    events = Adapter.Backdoor.events(history)

    assert [{:purge,  [given, "baz"],                   {:ok, %{}}},
            {:reject, [given, ^meta, []],               :ok},
            {:nack,   [given, ^meta, [multiple: true]], :ok},
            {:ack,    [given, ^meta, []],               :ok},
            {:get,    [given, "baz", []],               {:empty, %{}}},
            {:get,    [given, "baz", [no_ack: true]],   {:ok, "foo", ^meta}} | _] = Enum.reverse(events)
  end

  test "consume and cancel" do
    test_pid        = self
    {history, chan} = build_channel

    queue = Queue.new(chan, "foo")

    assert {:ok, queue} = Queue.consume(queue, no_ack: true)
    assert %{consuming: true, consuming_pid: ^test_pid, consumer_tag: tag} = queue
    assert {:consume,
            [_given, "foo", ^test_pid, [no_ack: true]],
            {:ok, ^tag}} = Adapter.Backdoor.last_event(history)

    assert {:error, :already_consuming} = Queue.consume(queue)

    assert {:ok, queue} = Queue.cancel(queue, [no_wait: true])
    assert %{consuming: false, consuming_pid: nil, consumer_tag: nil} = queue
    assert {:cancel,
            [_given, ^tag, [no_wait: true]],
            :ok} = Adapter.Backdoor.last_event(history)

    pid = spawn(fn -> :ok end)
    assert {:ok, _queue} = Queue.consume(queue, pid)
    assert {:consume,
            [_given, "foo", ^pid, []],
            {:ok, _new_tag}} = Adapter.Backdoor.last_event(history)
  end
end
