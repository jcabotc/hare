defmodule Hare.Context.Action.DeclareExchangeTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Exchange
  alias Hare.Context.Action.DeclareExchange
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [name: "foo",
              type: :fanout,
              opts: [durable: true]]

    assert :ok == DeclareExchange.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_present, :name, []}}
    assert error == DeclareExchange.validate([])

    error = {:error, {:not_binary, :name, :foo}}
    assert error == DeclareExchange.validate([name: :foo])

    error = {:error, {:not_atom, :type, "fanout"}}
    assert error == DeclareExchange.validate([name: "foo", type: "fanout"])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Core.Chan.new(given_chan, Adapter)

    config = [name: "foo", type: :fanout, opts: [durable: true]]
    assert {:ok, nil} = DeclareExchange.run(chan, config, %{})

    args = [given_chan, "foo", :fanout, [durable: true]]
    assert {:declare_exchange, args, :ok} == Adapter.Backdoor.last_event(history)

    minimal = [name: "foo", export_as: :foo]
    assert {:ok, nil, %{foo: exchange}} = DeclareExchange.run(chan, minimal, %{})
    assert %Exchange{chan: chan, name: "foo"} == exchange

    args = [given_chan, "foo", :direct, []]
    assert {:declare_exchange, args, :ok} == Adapter.Backdoor.last_event(history)
  end
end
