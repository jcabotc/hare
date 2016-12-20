defmodule Hare.Core.ExchangeTest do
  use ExUnit.Case, async: true

  alias Hare.Core.{Exchange, Chan}
  alias Hare.Adapter.Sandbox, as: Adapter

  setup do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)

    chan = Chan.new(given_chan, Adapter)

    {:ok, %{history: history, chan: chan}}
  end

  test "declare/4 and delete/2", %{history: history, chan: chan} do
    assert {:ok, exchange} = Exchange.declare(chan, "foo", :fanout, durable: true)
    assert exchange.chan == chan
    assert exchange.name == "foo"

    assert {:declare_exchange,
            [_given, "foo", :fanout, [durable: true]],
            :ok} = Adapter.Backdoor.last_event(history)

    assert {:ok, ^exchange} = Exchange.declare(chan, "foo")
    assert {:declare_exchange,
            [_given, "foo", :direct, []],
            :ok} = Adapter.Backdoor.last_event(history)

    assert :ok == Exchange.delete(exchange)
    assert {:delete_exchange,
            [_given, "foo", []],
            :ok} = Adapter.Backdoor.last_event(history)
  end

  test "new/2, publish/2 and /4", %{history: history, chan: chan} do
    exchange = Exchange.new(chan, "foo")

    assert :ok == Exchange.publish(exchange, "payload", "key.*", inmediate: true)
    assert {:publish,
            [_given, "foo", "payload", "key.*", [inmediate: true]],
            :ok} = Adapter.Backdoor.last_event(history)

    assert :ok == Exchange.publish(exchange, "payload")
    assert {:publish,
            [_given, "foo", "payload", "", []],
            :ok} = Adapter.Backdoor.last_event(history)
  end

  test "default/1", %{history: history, chan: chan} do
    exchange = Exchange.default(chan)

    assert :ok == Exchange.publish(exchange, "payload", "key.*", inmediate: true)
    assert {:publish,
            [_given, "", "payload", "key.*", [inmediate: true]],
            :ok} = Adapter.Backdoor.last_event(history)
  end
end
