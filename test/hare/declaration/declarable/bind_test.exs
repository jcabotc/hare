defmodule Hare.Declaration.BindTest do
  use ExUnit.Case, async: true

  alias Hare.Declaration.Declarable.Bind
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [queue:    "foo",
              exchange: "bar",
              opts:     [routing_key: "baz.*"]]

    assert :ok == Bind.validate(config)

    config = [queue_from_tag: :foo,
              exchange:       "bar",
              opts:           [routing_key: "baz.*"]]

    assert :ok == Bind.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_present, [:queue, :queue_from_tag], []}}
    assert error == Bind.validate([])

    error = {:error, {:not_binary, :queue, :foo}}
    assert error == Bind.validate([queue: :foo])

    error = {:error, {:not_atom, :queue_from_tag, "foo"}}
    assert error == Bind.validate([queue_from_tag: "foo"])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Chan.new(given_chan, Adapter)

    config = [queue:    "foo",
              exchange: "bar",
              opts: [durable: true]]
    assert :ok == Bind.run(chan, config, %{})

    args = [given_chan, "foo", "bar", [durable: true]]
    assert {:bind, args, :ok} == Adapter.Backdoor.last_event(history)

    minimal = [queue:    "foo",
               exchange: "bar"]
    assert :ok == Bind.run(chan, minimal, %{})

    args = [given_chan, "foo", "bar", []]
    assert {:bind, args, :ok} == Adapter.Backdoor.last_event(history)

    from_tag = [queue_from_tag: :baz,
                exchange:       "bar"]
    assert :ok == Bind.run(chan, from_tag, %{baz: "foo"})

    args = [given_chan, "foo", "bar", []]
    assert {:bind, args, :ok} == Adapter.Backdoor.last_event(history)
  end
end
