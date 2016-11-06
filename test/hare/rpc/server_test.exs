defmodule Hare.RPC.ServerTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Conn
  alias Hare.RPC.Server

  defmodule EchoTestServer do
    use Server

    def start_link(conn, config, pid),
      do: Server.start_link(__MODULE__, conn, config, pid)

    def handle_ready(meta, pid) do
      send(pid, {:ready, meta})
      {:noreply, pid}
    end

    def handle_message(payload, meta, pid) do
      send(pid, {:message, payload, meta})
      response =  "received: #{payload}"
      {:reply, response, pid}
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
                      opts: [no_ack: true]]]

    {:ok, rpc_server} = EchoTestServer.start_link(conn, config, self)

    send(rpc_server, {:consume_ok, %{bar: "baz"}})

    assert_receive {:ready, %{bar: "baz", queue: queue, exchange: exchange}}
    assert %{chan: chan, name: "foo"} = queue
    assert %{chan: ^chan, name: ""} = exchange

    payload = "a binary message"
    meta    = %{reply_to: "response_queue", correlation_id: 10}
    send(rpc_server, {:deliver, payload, meta})

    expected_meta = Map.merge(meta, %{queue: queue, exchange: exchange})
    assert_receive {:message, payload, ^expected_meta}

    reply   = "received: #{payload}"
    headers = [correlation_id: 10]
    assert [{:open_channel,    [_given_conn],                                         {:ok, given_chan}},
            {:declare_queue,   [given_chan, "foo", [no_ack: true]],                   {:ok, _info}},
            {:monitor_channel, [given_chan],                                          _ref},
            {:publish,         [given_chan, "", ^reply, "response_queue", ^headers],  :ok}
           ] = Adapter.Backdoor.last_events(history, 4)

    # Adapter.Backdoor.unlink(given_chan)
    # Adapter.Backdoor.crash(given_chan)
    #
    # assert [{:open_channel,    [_given_conn],                       {:ok, given_chan}},
    #         {:declare_queue,   [given_chan, "foo", [no_ack: true]], {:ok, _info}},
    #         {:monitor_channel, [given_chan],                        _ref},
    #        ] = Adapter.Backdoor.last_events(history, 3)
  end
end
