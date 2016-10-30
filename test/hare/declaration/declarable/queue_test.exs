defmodule Hare.Declaration.QueueTest do
  use ExUnit.Case, async: true

  alias Hare.Declaration.Declarable.Queue
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [name: "foo",
              opts: [durable: true]]

    assert :ok == Queue.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_present, :name, []}}
    assert error == Queue.validate([])

    error = {:error, {:not_binary, :name, :foo}}
    assert error == Queue.validate([name: :foo])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Chan.new(given_chan, Adapter)

    config = [name: "foo",
              opts: [durable: true]]
    Queue.run(chan, config, %{})

    args = [given_chan, "foo", [durable: true]]
    assert {:declare_queue, args, {:ok, %{}}} == Adapter.Backdoor.last_event(history)

    minimal = [name: "foo"]
    Queue.run(chan, minimal, %{})

    args = [given_chan, "foo", []]
    assert {:declare_queue, args, {:ok, %{}}} == Adapter.Backdoor.last_event(history)
  end
end
