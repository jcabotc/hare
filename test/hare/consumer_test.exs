defmodule Hare.ConsumerTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Conn
  alias Hare.Consumer

  defmodule TestConsumer do
    use Consumer

    def start_link(conn, config, pid),
      do: Consumer.start_link(__MODULE__, conn, config, pid)

    def handle_ready(meta, pid) do
      send(pid, {:ready, meta})
      {:noreply, pid}
    end

    def handle_message(payload, meta, pid) do
      send(pid, {:message, payload, meta})
      {:noreply, pid}
    end

    def handle_info(message, pid) do
      send(pid, {:info, message})
      {:noreply, pid}
    end

    def terminate(reason, pid),
      do: send(pid, {:terminate, reason})
  end

  alias Hare.Adapter.Sandbox, as: Adapter

  def build_conn do
    {:ok, history} = Adapter.Backdoor.start_history
    {:ok, conn} = Conn.start_link(config:  [history: history],
                                  adapter: Adapter,
                                  backoff: [10])

    {history, conn}
  end

  test "echo server" do
    {history, conn} = build_conn

    config = [exchange: [name: "foo",
                         type: :direct,
                         opts: [durable: true]],
              queue: [name: "bar",
                      opts: [no_ack: true]],
              bind: [routing_key: "baz"]]

    {:ok, rpc_server} = TestConsumer.start_link(conn, config, self)

    send(rpc_server, {:consume_ok, %{bar: "baz"}})
    assert_receive {:ready, %{bar: "baz", queue: queue, exchange: exchange}}
    assert %{chan: chan, name: "bar"} = queue
    assert %{chan: ^chan, name: "foo"} = exchange

    send(rpc_server, :some_message)
    assert_receive {:info, :some_message}

    payload = "some data"
    meta    = %{}
    send(rpc_server, {:deliver, payload, meta})

    expected_meta = Map.merge(meta, %{queue: queue, exchange: exchange})
    assert_receive {:message, ^payload, ^expected_meta}

    assert [{:open_channel,
              [_given_conn],
              {:ok, given_chan_1}},
            {:declare_exchange,
              [given_chan_1, "foo", :direct, [durable: true]],
              :ok},
            {:declare_queue,
              [given_chan_1, "bar", [no_ack: true]],
              {:ok, _info}},
            {:bind,
              [given_chan_1, "bar", "foo", [routing_key: "baz"]],
              :ok},
            {:consume,
              [given_chan_1, "bar", ^rpc_server, [no_ack: true]],
              {:ok, _consumer_tag}},
            {:monitor_channel,
              [given_chan_1],
              _ref}
           ] = Adapter.Backdoor.last_events(history, 6)

    Adapter.Backdoor.unlink(given_chan_1)
    Adapter.Backdoor.crash(given_chan_1)
    Process.sleep(5)

    payload = "another data"
    meta    = %{}

    send(rpc_server, {:deliver, payload, meta})
    assert_receive {:message, ^payload, _meta}
    Process.sleep(10)

    assert [{:open_channel,
              [_given_conn],
              {:ok, given_chan_2}},
            {:declare_exchange,
              [given_chan_2, "foo", :direct, [durable: true]],
              :ok},
            {:declare_queue,
              [given_chan_2, "bar", [no_ack: true]],
              {:ok, _info}},
            {:bind,
              [given_chan_2, "bar", "foo", [routing_key: "baz"]],
              :ok},
            {:consume,
              [given_chan_2, "bar", ^rpc_server, [no_ack: true]],
              {:ok, _consumer_tag}},
            {:monitor_channel,
              [given_chan_2],
              _ref}
           ] = Adapter.Backdoor.last_events(history, 6)

    assert given_chan_1 != given_chan_2
    assert given_chan_1.conn == given_chan_2.conn
  end
end
