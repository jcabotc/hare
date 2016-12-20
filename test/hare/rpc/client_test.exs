defmodule Hare.RPC.ClientTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Conn
  alias Hare.RPC.Client

  defmodule TestClient do
    use Client

    def start_link(conn, config, pid),
      do: Client.start_link(__MODULE__, conn, config, pid)

    def request(client, payload, opts),
      do: Client.request(client, payload, opts)

    def handle_ready(meta, pid) do
      send(pid, {:ready, meta})
      {:noreply, pid}
    end

    def handle_request(payload, opts, pid) do
      case Keyword.fetch(opts, :respond) do
        {:ok, "modify_request"}      -> {:ok, "foo - #{payload}", [bar: "baz"], pid}
        {:ok, "reply: " <> response} -> {:reply, response, pid}
        {:ok, "stop: " <> response}  -> {:stop, "a_reason", response, pid}
        _otherwise                   -> {:ok, pid}
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
    {history, conn} = build_conn

    config = [queue: [name: "foo",
                      opts: [durable: true]]]

    {:ok, rpc_client} = TestClient.start_link(conn, config, self)

    send(rpc_client, {:consume_ok, %{bar: "baz"}})
    assert_receive {:ready, %{bar:        "baz",
                              req_queue:  req_queue,
                              resp_queue: resp_queue,
                              exchange:   exchange}}

    assert %{chan: chan, name: "foo"} = req_queue
    assert %{chan: ^chan, name: resp_queue_name} = resp_queue
    assert %{chan: ^chan, name: ""} = exchange

    send(rpc_client, :some_message)
    assert_receive {:info, :some_message}

    payload = "the request"
    opts    = []
    request = Task.async fn ->
      TestClient.request(rpc_client, payload, opts)
    end
    assert nil == Task.yield(request, 30)

    assert [{:open_channel,
              [_given_conn],
              {:ok, given_chan_1}},
            {:declare_server_named_queue,
              [given_chan_1, [auto_delete: true, exclusive: true]],
              {:ok, ^resp_queue_name, _info_2}},
            {:declare_queue,
              [given_chan_1, "foo", [durable: true]],
              {:ok, _info_1}},
            {:consume,
              [given_chan_1, ^resp_queue_name, ^rpc_client, []],
              {:ok, _consumer_tag}},
            {:monitor_channel,
              [given_chan_1],
              _ref},
            {:publish,
              [given_chan_1, "", ^payload, "foo", opts],
              :ok}
           ] = Adapter.Backdoor.last_events(history, 6)

    assert resp_queue_name == Keyword.fetch!(opts, :reply_to)
    assert {:ok, correlation_id} = Keyword.fetch(opts, :correlation_id)

    response = "the response"
    meta     = %{correlation_id: correlation_id}
    send(rpc_client, {:deliver, response, meta})

    assert response == Task.await(request)
  end
end
