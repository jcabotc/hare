defmodule Hare.Declaration.ExchangeTest do
  use ExUnit.Case, async: true

  alias Hare.Declaration.Declarable.Exchange
  alias Hare.Adapter.Sandbox, as: Adapter

  test "validate/1" do
    config = [name: "foo",
              type: :fanout,
              opts: [durable: true]]

    assert :ok == Exchange.validate(config)
  end

  test "validate/1 on error" do
    error = {:error, {:not_present, :name, []}}
    assert error == Exchange.validate([])

    error = {:error, {:not_binary, :name, :foo}}
    assert error == Exchange.validate([name: :foo])

    error = {:error, {:not_atom, :type, "fanout"}}
    assert error == Exchange.validate([name: "foo", type: "fanout"])
  end

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Chan.new(given_chan, Adapter)

    config = [name: "foo",
              type: :fanout,
              opts: [durable: true]]
    assert :ok == Exchange.run(chan, config, %{})

    args = [given_chan, "foo", :fanout, [durable: true]]
    assert {:declare_exchange, args, :ok} == Adapter.Backdoor.last_event(history)

    minimal = [name: "foo"]
    assert :ok == Exchange.run(chan, minimal, %{})

    args = [given_chan, "foo", :direct, []]
    assert {:declare_exchange, args, :ok} == Adapter.Backdoor.last_event(history)
  end
end
