defmodule Hare.Context.Action.DeleteExchangeTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Exchange
  alias Hare.Context.Action.DeleteExchange
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [name: "foo",
              opts: [no_wait: true]]

    assert :ok == DeleteExchange.validate(config)

    config = [exchange_from_export: :exchange]

    assert :ok == DeleteExchange.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_present, [:name, :exchange_from_export], []}}
    assert error == DeleteExchange.validate([])

    error = {:error, {:not_binary, :name, :foo}}
    assert error == DeleteExchange.validate([name: :foo])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Core.Chan.new(given_chan, Adapter)

    config = [name: "foo", opts: [no_wait: true]]
    assert {:ok, nil} = DeleteExchange.run(chan, config, %{})

    args = [given_chan, "foo", [no_wait: true]]
    assert {:delete_exchange, args, :ok} == Adapter.Backdoor.last_event(history)

    minimal = [name: "foo", export_as: :foo]
    assert {:ok, nil, %{foo: exchange}} = DeleteExchange.run(chan, minimal, %{})
    assert %Exchange{chan: chan, name: "foo"} == exchange

    args = [given_chan, "foo", []]
    assert {:delete_exchange, args, :ok} == Adapter.Backdoor.last_event(history)
  end
end
