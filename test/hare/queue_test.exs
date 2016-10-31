defmodule Hare.QueueTest do
  use ExUnit.Case, async: true

  alias Hare.{Queue, Chan}
  alias Hare.Adapter.Sandbox, as: Adapter

  test "publish/2 and /4" do
    messages = ["foo", "bar"]

    {:ok, history}  = Adapter.Backdoor.start_history
    {:ok, messages} = Adapter.Backdoor.messages(messages)
    config = [history: history, messages: messages]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)

    channel = Chan.new(given_chan, Adapter)
    name    = "baz"

    queue = Queue.new(channel, name)

    assert {:ok, "foo", meta} = Queue.get(queue, no_ack: true)

    args = [given_chan, "baz", [no_ack: true]]
    assert {:get, args, {:ok, "foo", meta}} == Adapter.Backdoor.last_event(history)

    assert {:ok, "bar", meta} = Queue.get(queue)

    args = [given_chan, "baz", []]
    assert {:get, args, {:ok, "bar", meta}} == Adapter.Backdoor.last_event(history)

    assert {:empty, %{}} = Queue.get(queue)

    args = [given_chan, "baz", []]
    assert {:get, args, {:empty, %{}}} == Adapter.Backdoor.last_event(history)
  end
end
