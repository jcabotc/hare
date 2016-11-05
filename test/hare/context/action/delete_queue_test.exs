defmodule Hare.Context.Action.DeleteQueueTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Queue
  alias Hare.Context.Action.DeleteQueue
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [name: "foo",
              opts: [no_wait: true]]

    assert :ok == DeleteQueue.validate(config)

    config = [queue_from_export: :queue]

    assert :ok == DeleteQueue.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_present, [:name, :queue_from_export], []}}
    assert error == DeleteQueue.validate([])

    error = {:error, {:not_binary, :name, :foo}}
    assert error == DeleteQueue.validate([name: :foo])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Core.Chan.new(given_chan, Adapter)

    config = [name: "foo", opts: [no_wait: true]]
    assert {:ok, nil} = DeleteQueue.run(chan, config, %{})

    args = [given_chan, "foo", [no_wait: true]]
    assert {:delete_queue, args, :ok} == Adapter.Backdoor.last_event(history)

    minimal = [name: "foo", export_as: :foo]
    assert {:ok, nil, %{foo: queue}} = DeleteQueue.run(chan, minimal, %{})
    assert %Queue{chan: chan, name: "foo"} == queue

    args = [given_chan, "foo", []]
    assert {:delete_queue, args, :ok} == Adapter.Backdoor.last_event(history)
  end
end
