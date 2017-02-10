defmodule Hare.PublisherTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Conn
  alias Hare.Publisher

  defmodule TestPublisher do
    use Publisher

    def start_link(conn, config, pid),
      do: Publisher.start_link(__MODULE__, conn, config, pid)

    def publish(client, payload),
      do: Publisher.publish(client, payload)
    def publish(client, payload, routing_key, opts),
      do: Publisher.publish(client, payload, routing_key, opts)

    def handle_publication(payload, routing_key, opts, pid) do
      case Keyword.fetch(opts, :hook) do
        {:ok, "modify_publication"} -> {:ok, "ASDF - #{payload}", routing_key, [bar: "baz"], pid}
        {:ok, "ignore"}             -> {:ignore, pid}
        {:ok, "stop"}               -> {:stop, "a_reason", pid}
        _otherwise                  -> {:ok, pid}
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

  test "publication" do
    {history, conn} = build_conn()

    config = [exchange: [name: "foo",
                         type: :fanout,
                         opts: [durable: true]]]

    {:ok, rpc_client} = TestPublisher.start_link(conn, config, self())

    send(rpc_client, :some_message)
    assert_receive {:info, :some_message}

    payload     = "some data"
    routing_key = "the key"

    Process.unlink(rpc_client)
    assert :ok == TestPublisher.publish(rpc_client, payload, routing_key, [])
    assert :ok == TestPublisher.publish(rpc_client, payload, routing_key, hook: "modify_publication")
    assert :ok == TestPublisher.publish(rpc_client, payload, routing_key, hook: "ignore")
    assert :ok == TestPublisher.publish(rpc_client, payload, routing_key, hook: "stop")

    Process.sleep(20)

    assert [{:open_channel,
              [_given_conn],
              {:ok, given_chan_1}},
            {:declare_exchange,
              [given_chan_1, "foo", :fanout, [durable: true]],
              :ok},
            {:monitor_channel,
              [given_chan_1],
              _ref},
            {:publish,
              [given_chan_1, "foo", ^payload, ^routing_key, []],
              :ok},
            {:publish,
              [given_chan_1, "foo", "ASDF - " <> ^payload, ^routing_key, [bar: "baz"]],
              :ok},
            {:close_channel,
              [given_chan_1],
              :ok}
           ] = Adapter.Backdoor.last_events(history, 6)
  end
end
