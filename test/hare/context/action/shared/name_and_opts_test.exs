defmodule Hare.Action.Shared.NameAndOptsTest do
  use ExUnit.Case, async: true

  alias Hare.Action.Shared.NameAndOpts
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [name: "foo",
              opts: [durable: true]]

    assert :ok == NameAndOpts.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_present, :name, []}}
    assert error == NameAndOpts.validate([])

    error = {:error, {:not_binary, :name, :foo}}
    assert error == NameAndOpts.validate([name: :foo])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Core.Chan.new(given_chan, Adapter)

    config = [name: "foo",
              opts: [durable: true]]
    assert {:ok, %{}} == NameAndOpts.run(chan, :declare_queue, config)

    args = [given_chan, "foo", [durable: true]]
    assert {:declare_queue, args, {:ok, %{}}} == Adapter.Backdoor.last_event(history)

    minimal = [name: "foo"]
    assert {:ok, %{}} == NameAndOpts.run(chan, :declare_queue, minimal)

    args = [given_chan, "foo", []]
    assert {:declare_queue, args, {:ok, %{}}} == Adapter.Backdoor.last_event(history)
  end
end
