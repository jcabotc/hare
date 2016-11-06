defmodule Hare.Context.Action.DeclareServerNamedQueueTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Queue
  alias Hare.Context.Action.DeclareServerNamedQueue
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [export_as: :foo,
              opts:      [durable: true]]

    assert :ok == DeclareServerNamedQueue.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_atom, :export_as, "foo"}}
    assert error == DeclareServerNamedQueue.validate([export_as: "foo"])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Core.Chan.new(given_chan, Adapter)

    config = [export_as: :foo, opts: [durable: true]]
    assert {:ok, info, %{foo: queue}} = DeclareServerNamedQueue.run(chan, config, %{})
    assert %Queue{chan: ^chan, name: name} = queue
    assert Regex.match?(~r/generated_name_/, name)

    last_event = Adapter.Backdoor.last_event(history)
    args = [given_chan, [durable: true]]
    assert {:declare_server_named_queue, args, {:ok, name, info}} == last_event

    minimal = []
    assert {:ok, info} = DeclareServerNamedQueue.run(chan, minimal, %{})

    last_event = Adapter.Backdoor.last_event(history)
    args = [given_chan, []]
    assert {:declare_server_named_queue, ^args, {:ok, _name, ^info}} = last_event
  end
end
