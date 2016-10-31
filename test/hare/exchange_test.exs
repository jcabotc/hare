defmodule Hare.ExchangeTest do
  use ExUnit.Case, async: true

  alias Hare.{Exchange, Chan}
  alias Hare.Adapter.Sandbox, as: Adapter

  test "publish/2 and /4" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)

    channel = Chan.new(given_chan, Adapter)
    name    = "foo"

    exchange = Exchange.new(channel, name)

    assert :ok == Exchange.publish(exchange, "payload", "key.*", inmediate: true)

    args = [given_chan, "foo", "payload", "key.*", [inmediate: true]]
    assert {:publish, args, :ok} == Adapter.Backdoor.last_event(history)
  end
end
