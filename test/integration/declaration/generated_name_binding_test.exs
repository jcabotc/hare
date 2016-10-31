defmodule Hare.IntegrationTest.Declaration.GeneratedNameBindingTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Declaration
  alias Hare.Adapter.Sandbox, as: Adapter

  test "run/2" do
    {:ok, history} = Adapter.Backdoor.start_history
    config = [history: history]

    {:ok, given_conn} = Adapter.open_connection(config)
    {:ok, given_chan} = Adapter.open_channel(given_conn)
    chan = Hare.Core.Chan.new(given_chan, Adapter)

    steps = [
      server_named_queue: [
        tag:  :temporary_queue,
        opts: [exclusive: true, auto_delete: true]],
      exchange: [
        name: "events",
        type: :topic,
        opts: [durable: true]],
      bind: [
        queue_from_tag: :temporary_queue,
        exchange:       "events",
        opts:           [routing_key: "log.*"]]]

    assert {:ok, result} = Declaration.run(chan, steps)

    assert [
      server_named_queue: %{
        status: :success,
        config: [tag: :temporary_queue, opts: [exclusive: true, auto_delete: true]],
        info:   %{}},
      exchange: %{
        status: :success,
        config: [name: "events", type: :topic, opts: [durable: true]],
        info:   nil},
      bind: %{
        status: :success,
        config: [queue_from_tag: :temporary_queue, exchange: "events", opts: [routing_key: "log.*"]],
        info:   nil}] = Declaration.Result.steps(result)

    assert %{temporary_queue: queue} = result.tags

    expected_events = [
      {:open_connection,            [config],                                              {:ok, given_conn}},
      {:open_channel,               [given_conn],                                          {:ok, given_chan}},
      {:declare_server_named_queue, [given_chan, [exclusive: true, auto_delete: true]],    {:ok, queue, %{}}},
      {:declare_exchange,           [given_chan, "events", :topic, [durable: true]],       :ok},
      {:bind,                       [given_chan, queue, "events", [routing_key: "log.*"]], :ok}]

    assert expected_events == Adapter.Backdoor.events(history)
  end
end
