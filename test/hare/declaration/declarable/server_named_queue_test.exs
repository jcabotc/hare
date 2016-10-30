defmodule Hare.Declaration.Declarable.ServerNamedQueueTest do
  use ExUnit.Case, async: true

  alias Hare.Declaration.Declarable.ServerNamedQueue
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [tag:  :foo,
              opts: [durable: true]]

    assert :ok == ServerNamedQueue.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_present, :tag, []}}
    assert error == ServerNamedQueue.validate([])

    error = {:error, {:not_atom, :tag, "foo"}}
    assert error == ServerNamedQueue.validate([tag: "foo"])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Chan.new(given_chan, Adapter)

    config = [tag:  :foo,
              opts: [durable: true]]
    assert {:ok, %{}, %{foo: name}} = ServerNamedQueue.run(chan, config, %{})
    assert Regex.match?(~r/generated_name_/, name)

    last_event = Adapter.Backdoor.last_event(history)
    args = [given_chan, [durable: true]]
    assert {:declare_server_named_queue, args, {:ok, name, %{}}} == last_event

    minimal = [tag: :foo]
    assert {:ok, %{}, %{foo: name}} = ServerNamedQueue.run(chan, minimal, %{})
    assert Regex.match?(~r/generated_name_/, name)

    last_event = Adapter.Backdoor.last_event(history)
    args = [given_chan, []]
    assert {:declare_server_named_queue, args, {:ok, name, %{}}} == last_event
  end
end
