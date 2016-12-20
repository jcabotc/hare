defmodule Hare.Context.Action.DeclareQueueTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Queue
  alias Hare.Context.Action.DeclareQueue
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [name: "foo",
              opts: [durable: true]]

    assert :ok == DeclareQueue.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_present, :name, []}}
    assert error == DeclareQueue.validate([])

    error = {:error, {:not_binary, :name, :foo}}
    assert error == DeclareQueue.validate([name: :foo])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Core.Chan.new(given_chan, Adapter)

    config = [name: "foo", opts: [durable: true]]
    assert {:ok, info} = DeclareQueue.run(chan, config, %{})

    args = [given_chan, "foo", [durable: true]]
    assert {:declare_queue, args, {:ok, info}} == Adapter.Backdoor.last_event(history)

    minimal = [name: "foo", export_as: :foo]
    assert {:ok, info, %{foo: queue}} = DeclareQueue.run(chan, minimal, %{})
    assert %Queue{chan: chan, name: "foo"} == queue

    args = [given_chan, "foo", []]
    assert {:declare_queue, args, {:ok, info}} == Adapter.Backdoor.last_event(history)
  end
end
