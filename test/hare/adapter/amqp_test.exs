defmodule Hare.Adapter.AMQPTest do
  use ExUnit.Case, async: true
  @moduletag :amqp_server

  alias Hare.Adapter.AMQP, as: Adapter
  @config Application.get_env(:hare, :conn_config)

  @exchange %{name: "__test__.hare_adapter_amqp_test_exchange",
              type: :direct,
              opts: [durable: false, auto_delete: true]}

  @queue %{name: "__test__.hare_adapter_amqp_test_queue",
           opts: [durable: false, auto_delete: true]}

  @routing_key "valid"

  def receive_message(timeout \\ 100) do
    receive do
      message -> message
    after
      timeout -> raise "receive timeout"
    end
  end

  test "publish and consume messages" do
    assert {:ok, conn} = Adapter.open_connection(@config)
    assert {:ok, chan} = Adapter.open_channel(conn)

    %{name: exchange, type: type, opts: opts} = @exchange
    assert :ok = Adapter.declare_exchange(chan, exchange, type, opts)

    %{name: queue, opts: opts} = @queue
    assert {:ok, _info} = Adapter.declare_queue(chan, queue, opts)

    opts = [routing_key: @routing_key]
    assert :ok = Adapter.bind(chan, queue, exchange, opts)

    payload = "first payload"
    assert :ok = Adapter.publish(chan, exchange, payload, @routing_key, [])

    assert {:ok, ^payload, meta} = Adapter.get(chan, queue, [])
    assert :ok = Adapter.reject(chan, meta, [])

    assert {:ok, consumer_tag} = Adapter.consume(chan, queue, self(), [])
    message = receive_message()
    assert {:consume_ok, _meta} = Adapter.handle(message)

    message = receive_message()
    assert {:deliver, ^payload, meta} = Adapter.handle(message)
    assert :ok = Adapter.ack(chan, meta, [])

    assert :ok = Adapter.cancel(chan, consumer_tag, [])
    message = receive_message()
    assert {:cancel_ok, _meta} = Adapter.handle(message)

    assert :ok = Adapter.unbind(chan, queue, exchange, [])
    assert :ok = Adapter.delete_exchange(chan, exchange, [])
    assert {:ok, _info} = Adapter.delete_queue(chan, queue, [])

    assert :ok = Adapter.close_channel(chan)
    assert :ok = Adapter.close_connection(conn)
  end

  test "link and monitor" do
    Process.flag(:trap_exit, true)

    assert {:ok, %{pid: conn_pid} = conn} = Adapter.open_connection(@config)
    conn_ref = Adapter.monitor_connection(conn)

    assert {:ok, %{pid: chan_pid} = chan} = Adapter.open_channel(conn)
    assert true = Adapter.link_channel(chan)
    chan_ref = Adapter.monitor_channel(chan)

    Process.exit(conn_pid, :kill)
    assert_receive {:DOWN, ^conn_ref, _, _, :killed}
    assert_receive {:DOWN, ^chan_ref, _, _, :killed}
    assert_receive {:EXIT, ^chan_pid, :killed}
  end
end
