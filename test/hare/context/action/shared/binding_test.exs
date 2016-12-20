defmodule Hare.Context.Action.Shared.BindingTest do
  use ExUnit.Case, async: true

  alias Hare.Core.{Queue, Exchange}
  alias Hare.Context.Action.Shared.Binding
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [queue:    "foo",
              exchange: "bar",
              opts:     [routing_key: "baz.*"]]

    assert :ok == Binding.validate(config)

    config = [queue_from_export: :foo,
              exchange:          "bar",
              opts:              [routing_key: "baz.*"]]

    assert :ok == Binding.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_present, [:queue, :queue_from_export], []}}
    assert error == Binding.validate([])

    error = {:error, {:not_binary, :queue, :foo}}
    assert error == Binding.validate([queue: :foo])

    error = {:error, {:not_atom, :queue_from_export, "foo"}}
    assert error == Binding.validate([queue_from_export: "foo"])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)

    chan        = Hare.Core.Chan.new(given_chan, Adapter)
    binding_fun = &Queue.bind/3

    config = [queue: "foo", exchange: "bar", opts: [durable: true]]
    assert {:ok, nil} == Binding.run(binding_fun, chan, config, %{})

    args = [given_chan, "foo", "bar", [durable: true]]
    assert {:bind, args, :ok} == Adapter.Backdoor.last_event(history)

    minimal = [queue: "foo", exchange: "bar", export_as: :baz]
    assert {:ok, nil, %{baz: {queue, exchange}}} = Binding.run(binding_fun, chan, minimal, %{})
    assert %Queue{chan: chan, name: "foo"} == queue
    assert %Exchange{chan: chan, name: "bar"} == exchange

    args = [given_chan, "foo", "bar", []]
    assert {:bind, args, :ok} == Adapter.Backdoor.last_event(history)

    from_export = [queue_from_export: :queue, exchange_from_export: :exchange]
    exports = %{queue: queue, exchange: exchange}
    assert {:ok, nil} == Binding.run(binding_fun, chan, from_export, exports)

    args = [given_chan, "foo", "bar", []]
    assert {:bind, args, :ok} == Adapter.Backdoor.last_event(history)
  end
end
