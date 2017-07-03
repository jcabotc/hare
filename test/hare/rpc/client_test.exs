defmodule Hare.RPC.ClientTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Conn
  alias Hare.RPC.Client

  defmodule TestClient do
    use Client

    def start_link(conn, config, pid),
      do: Client.start_link(__MODULE__, conn, config, pid)

    def request(client, payload),
      do: Client.request(client, payload)
    def request(client, payload, routing_key, opts),
      do: Client.request(client, payload, routing_key, opts)

    def handle_ready(meta, pid) do
      send(pid, {:ready, meta})
      {:noreply, pid}
    end

    def handle_connected(pid) do
      send(pid, :connected)
      {:noreply, pid}
    end

    def before_request(payload, routing_key, opts, _from, pid) do
      case Keyword.fetch(opts, :hook) do
        {:ok, "modify_request"} ->
          {:ok, "ASDF - #{payload}", routing_key, [bar: "baz"], pid}

        {:ok, "correlation_id"} ->
          send(pid, {:correlation_id, opts[:correlation_id]})
          {:ok, pid}

        {:ok, "reply: " <> response} ->
          {:reply, {:ok, response}, pid}

        {:ok, "stop: " <> response} ->
          {:stop, "a_reason", {:ok, response}, pid}

        _otherwise ->
          {:ok, pid}
      end
    end

    def on_response(response, _from, pid) do
      case response do
        "noreply"  -> {:noreply, pid}
        "modify"   -> {:reply, {:ok, "modified_response"}, pid}
        _otherwise -> {:reply, {:ok, response}, pid}
      end
    end

    def on_return(_from, pid) do
      {:reply, "no_route", pid}
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
                         type: :fanout,
                         opts: [durable: true]]]

    {:ok, rpc_client} = TestClient.start_link(conn, config, self())
    assert_receive :connected

    send(rpc_client, {:consume_ok, %{bar: "baz"}})
    assert_receive {:ready, %{bar:          "baz",
                              resp_queue:   resp_queue,
                              req_exchange: req_exchange}}

    assert %{chan: chan,  name: resp_queue_name} = resp_queue
    assert %{chan: ^chan, name: "foo"} = req_exchange

    send(rpc_client, :some_message)
    assert_receive {:info, :some_message}

    payload     = "the request"
    routing_key = "the key"

    request_1 = Task.async fn ->
      TestClient.request(rpc_client, payload, routing_key, [])
    end
    request_2 = Task.async fn ->
      TestClient.request(rpc_client, payload, routing_key, [])
    end
    request_3 = Task.async fn ->
      TestClient.request(rpc_client, payload, routing_key, hook: "modify_request")
    end
    request_4 = Task.async fn ->
      TestClient.request(rpc_client, payload, routing_key, [])
    end
    request_5 = Task.async fn ->
      TestClient.request(rpc_client, payload, routing_key, hook: "correlation_id")
    end
    assert_receive {:correlation_id, correlation_id_5}

    assert nil == Task.yield(request_1, 20)
    assert nil == Task.yield(request_2, 1)
    assert nil == Task.yield(request_3, 1)
    assert nil == Task.yield(request_4, 1)
    assert nil == Task.yield(request_5, 1)

    assert {:ok, "hi!"} = TestClient.request(rpc_client, payload, routing_key, hook: "reply: hi!")

    assert [{:open_channel,
              [_given_conn],
              {:ok, given_chan_1}},
            {:monitor_channel,
              [given_chan_1],
              _ref},
            {:declare_server_named_queue,
              [given_chan_1, [auto_delete: true, exclusive: true]],
              {:ok, ^resp_queue_name, _info_2}},
            {:declare_exchange,
              [given_chan_1, "foo", :fanout, [durable: true]],
              :ok},
            {:consume,
              [given_chan_1, ^resp_queue_name, ^rpc_client, [no_ack: true]],
              {:ok, _consumer_tag}},
            {:register_return_handler,
              [given_chan_1, ^rpc_client],
              :ok},
            {:publish,
              [given_chan_1, "foo", ^payload, ^routing_key, opts_1],
              :ok},
            {:publish,
              [given_chan_1, "foo", ^payload, ^routing_key, opts_2],
              :ok},
            {:publish,
              [given_chan_1, "foo", "ASDF - " <> ^payload, ^routing_key, opts_3],
              :ok},
            {:publish,
              [given_chan_1, "foo", ^payload, ^routing_key, opts_4],
              :ok},
            {:publish,
              [given_chan_1, "foo", ^payload, ^routing_key, opts_5],
              :ok}
           ] = Adapter.Backdoor.last_events(history, 11)

    assert resp_queue_name == Keyword.fetch!(opts_1, :reply_to)
    correlation_id_1 = Keyword.fetch!(opts_1, :correlation_id)

    assert resp_queue_name == Keyword.fetch!(opts_2, :reply_to)
    correlation_id_2 = Keyword.fetch!(opts_2, :correlation_id)

    assert resp_queue_name == Keyword.fetch!(opts_3, :reply_to)
    assert "baz"           == Keyword.fetch!(opts_3, :bar)
    correlation_id_3 = Keyword.fetch!(opts_3, :correlation_id)

    assert resp_queue_name == Keyword.fetch!(opts_4, :reply_to)
    correlation_id_4 = Keyword.fetch!(opts_4, :correlation_id)

    assert resp_queue_name == Keyword.fetch!(opts_5, :reply_to)
    assert correlation_id_5 == Keyword.fetch!(opts_5, :correlation_id)

    response_2 = "a_response"
    meta_2     = %{correlation_id: correlation_id_2}
    send(rpc_client, {:deliver, response_2, meta_2})

    assert {:ok, response_2} == Task.await(request_2)

    response_3 = "modify"
    meta_3     = %{correlation_id: correlation_id_3}
    send(rpc_client, {:deliver, response_3, meta_3})

    assert {:ok, "modified_response"} == Task.await(request_3)

    response_1 = "noreply"
    meta_1     = %{correlation_id: correlation_id_1}
    send(rpc_client, {:deliver, response_1, meta_1})

    assert nil == Task.yield(request_1, 10)

    meta_4     = %{correlation_id: correlation_id_4}
    send(rpc_client, {:return, payload, meta_4})

    assert {:ok, "no_route"} == Task.yield(request_4, 10)

    response_5 = "a_response"
    meta_5     = %{correlation_id: correlation_id_5}
    send(rpc_client, {:deliver, response_5, meta_5})

    assert {:ok, response_5} == Task.await(request_5)
  end

  test "timeout" do
    {history, conn} = build_conn()

    config = [exchange: [name: "foo",
                         type: :fanout,
                         opts: [durable: true]],
              timeout: 1]

    {:ok, rpc_client} = TestClient.start_link(conn, config, self())

    payload = "the request"
    request = Task.async fn ->
      TestClient.request(rpc_client, payload)
    end

    Process.sleep(5)
    assert {:error, :timeout} == Task.await(request)

    Process.unlink(rpc_client)
    assert {:ok, "bye!"} = TestClient.request(rpc_client, payload, "", hook: "stop: bye!")

    [{:publish,
       [given_chan, "foo", ^payload, "", _opts],
       :ok},
     {:unregister_return_handler,
       [given_chan],
       :ok},
     {:close_channel,
       [given_chan],
       :ok}
    ] = Adapter.Backdoor.last_events(history, 3)
  end

  test "disconnect during request" do
    {:ok, conn} = Conn.start_link(config:  [],
                                  adapter: Adapter,
                                  backoff: [500])

    config = [exchange: [name: "foo", type: :fanout]]

    {:ok, rpc_client} = TestClient.start_link(conn, config, self())
    assert_receive :connected

    send(rpc_client, {:consume_ok, %{bar: "baz"}})

    payload = "the request"
    request = Task.async fn ->
      TestClient.request(rpc_client, payload)
    end

    # crash connection
    Adapter.Backdoor.crash(Hare.Conn.given_conn(conn), :normal)

    assert {:error, :disconnected} = Task.await(request)
    assert {:error, :not_connected} = TestClient.request(rpc_client, payload)
  end
end
