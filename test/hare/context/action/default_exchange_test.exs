defmodule Hare.Context.Action.DefaultExchangeTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Exchange
  alias Hare.Context.Action.DefaultExchange
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [export_as: :foo]

    assert :ok == DefaultExchange.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_atom, :export_as, "foo"}}
    assert error == DefaultExchange.validate([export_as: "foo"])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Core.Chan.new(given_chan, Adapter)

    config = [export_as: :foo]
    assert {:ok, nil, %{foo: exchange}} = DefaultExchange.run(chan, config, %{})
    assert %Exchange{chan: chan, name: ""} == exchange
  end
end
