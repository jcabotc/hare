defmodule Hare.IntegrationTest.Context.GeneratedNameBindingTest do
  use ExUnit.Case, async: true

  alias Hare.Context
  alias Hare.Core.{Queue, Exchange}
  alias Hare.Adapter.Sandbox, as: Adapter

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Core.Chan.new(given_chan, Adapter)

    queue_config = [opts:      [exclusive: true, auto_delete: true],
                    export_as: :temporary_queue]

    exchange_config = [name:      "events",
                       type:      :topic,
                       opts:      [durable: true],
                       export_as: :events_exchange]

    bind_config = [queue_from_export:    :temporary_queue,
                   exchange_from_export: :events_exchange,
                   opts:                 [routing_key: "log.*"]]

    steps = [server_named_queue: queue_config,
             exchange:           exchange_config,
             bind:               bind_config]

    assert {:ok, result} = Context.run(chan, steps)

    assert [server_named_queue: %{status: :success, config: ^queue_config,    info: %{}},
            exchange:           %{status: :success, config: ^exchange_config, info: nil},
            bind:               %{status: :success, config: ^bind_config,     info: nil}
            ] = Context.Result.steps(result)

    assert %{temporary_queue: queue, events_exchange: exchange} = result.exports
    assert %Queue{chan: ^chan, name: queue_name} = queue
    assert %Exchange{chan: chan, name: "events"} == exchange

    assert [{:open_connection,            [^config],                                                    {:ok, ^given_conn}},
            {:open_channel,               [^given_conn],                                                {:ok, ^given_chan}},
            {:declare_server_named_queue, [^given_chan, [exclusive: true, auto_delete: true]],          {:ok, ^queue_name, %{}}},
            {:declare_exchange,           [^given_chan, "events", :topic, [durable: true]],             :ok},
            {:bind,                       [^given_chan, ^queue_name, "events", [routing_key: "log.*"]], :ok}
            ] = Adapter.Backdoor.events(history)
  end
end
