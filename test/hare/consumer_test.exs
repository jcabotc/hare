defmodule Hare.ConsumerTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Conn
  alias Hare.Consumer

  defmodule TestConsumer do
    use Consumer

    def start_link(conn, config, pid),
      do: Consumer.start_link(__MODULE__, conn, config, pid)

    def handle_connected(pid) do
      send(pid, :connected)
      {:noreply, pid}
    end

    def handle_ready(meta, pid) do
      send(pid, {:ready, meta})
      {:noreply, pid}
    end

    def handle_message(payload, meta, pid) do
      send(pid, {:message, payload, meta})

      case payload do
        "ack" <> _rest    -> {:reply, :ack, pid}
        "nack" <> _rest   -> {:reply, :nack, pid}
        "reject" <> _rest -> {:reply, :reject, [requeue: true], pid}
        _otherwise        -> {:noreply, pid}
      end
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
    {history, conn} = build_conn()

    config = [exchange: [name: "foo",
                         type: :direct,
                         opts: [durable: true]],
              queue: [name: "bar",
                      opts: []],
              bind: [routing_key: "baz"],
              bind: [routing_key: "qux"]]

    {:ok, consumer} = TestConsumer.start_link(conn, config, self())
    assert_receive :connected

    send(consumer, {:consume_ok, %{bar: "baz"}})
    assert_receive {:ready, %{bar: "baz", queue: queue, exchange: exchange}}
    assert %{chan: chan, name: "bar"} = queue
    assert %{chan: ^chan, name: "foo"} = exchange

    send(consumer, :some_message)
    assert_receive {:info, :some_message}

    payload = "some data"
    meta    = %{}

    send(consumer, {:deliver, "ack - #{payload}", meta})
    send(consumer, {:deliver, "nack - #{payload}", meta})
    send(consumer, {:deliver, "reject - #{payload}", meta})
    send(consumer, {:deliver, payload, meta})

    expected_meta = Map.merge(meta, %{queue: queue, exchange: exchange})
    assert_receive {:message, ^payload,                ^expected_meta}
    assert_receive {:message, "ack - " <> ^payload,    ^expected_meta}
    assert_receive {:message, "nack - " <> ^payload,   ^expected_meta}
    assert_receive {:message, "reject - " <> ^payload, ^expected_meta}

    assert [{:open_channel,
              [_given_conn],
              {:ok, given_chan_1}},
            {:monitor_channel,
              [given_chan_1],
              _ref},
            {:declare_exchange,
              [given_chan_1, "foo", :direct, [durable: true]],
              :ok},
            {:declare_queue,
              [given_chan_1, "bar", []],
              {:ok, _info}},
            {:bind,
              [given_chan_1, "bar", "foo", [routing_key: "baz"]],
              :ok},
            {:bind,
              [given_chan_1, "bar", "foo", [routing_key: "qux"]],
              :ok},
            {:consume,
              [given_chan_1, "bar", ^consumer, []],
              {:ok, _consumer_tag}},
            {:ack,
              [given_chan_1, _meta_ack, []],
              :ok},
            {:nack,
              [given_chan_1, _meta_nack, []],
              :ok},
            {:reject,
              [given_chan_1, _meta_reject, [requeue: true]],
              :ok}
           ] = Adapter.Backdoor.last_events(history, 10)

    Adapter.Backdoor.unlink(given_chan_1)
    Adapter.Backdoor.crash(given_chan_1)
    Process.sleep(5)

    payload = "another data"
    meta    = %{}

    send(consumer, {:deliver, payload, meta})
    assert_receive {:message, ^payload, _meta}
    Process.sleep(10)

    assert [{:open_channel,
              [_given_conn],
              {:ok, given_chan_2}},
            {:monitor_channel,
              [given_chan_2],
              _ref},
            {:declare_exchange,
              [given_chan_2, "foo", :direct, [durable: true]],
              :ok},
            {:declare_queue,
              [given_chan_2, "bar", []],
              {:ok, _info}},
            {:bind,
              [given_chan_2, "bar", "foo", [routing_key: "baz"]],
              :ok},
            {:bind,
              [given_chan_2, "bar", "foo", [routing_key: "qux"]],
              :ok},
            {:consume,
              [given_chan_2, "bar", ^consumer, []],
              {:ok, _consumer_tag}}
           ] = Adapter.Backdoor.last_events(history, 7)

    assert given_chan_1 != given_chan_2
    assert given_chan_1.conn == given_chan_2.conn
  end
end
