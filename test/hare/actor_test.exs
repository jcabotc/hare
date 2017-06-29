defmodule Hare.ActorTest do
  use ExUnit.Case, async: true

  defmodule TestActor do
    use Hare.Actor

    def start_link(conn, test_pid),
      do: Hare.Actor.start_link(__MODULE__, conn, test_pid)

    defdelegate call(actor, message), to: Hare.Actor
    defdelegate cast(actor, message), to: Hare.Actor

    def connected(chan, pid) do
      send(pid, {:connected, chan})
      {:ok, pid}
    end

    def disconnected(reason, pid) do
      send(pid, {:disconnected, reason})
      {:ok, pid}
    end

    def handle_call(:do_reply_directly, _from, pid) do
      {:reply, :direct_reply, pid}
    end
    def handle_call(:do_reply_indirectly, from, pid) do
      Hare.Actor.reply(from, :indirect_reply)
      {:noreply, pid}
    end

    def handle_cast({:do_stop, reason}, pid) do
      {:stop, reason, pid}
    end
    def handle_cast(message, pid) do
      send(pid, {:cast, message})
      {:noreply, pid}
    end

    def handle_info(message, pid) do
      send(pid, {:info, message})
      {:noreply, pid}
    end

    def terminate(reason, pid) do
      send(pid, {:terminate, reason})
    end
  end

  alias Hare.Adapter.Sandbox, as: Adapter

  test "everything" do
    test_pid = self()

    {:ok, history} = Adapter.Backdoor.start_history()

    config = [adapter: Adapter,
              config:  [history: history]]

    {:ok, conn} = Hare.Conn.start_link(config)

    # init and connect
    #
    {:ok, actor} = TestActor.start_link(conn, test_pid)
    assert_receive {:connected, chan_1}

    # handle_call
    #
    assert :direct_reply   == TestActor.call(actor, :do_reply_directly)
    assert :indirect_reply == TestActor.call(actor, :do_reply_indirectly)

    # on chan crash
    #
    Adapter.Backdoor.crash(chan_1.given, :normal)
    assert_receive {:disconnected, :normal}
    assert_receive {:connected, chan_2}
    assert chan_1 != chan_2

    # handle_info
    #
    send(actor, "baz")
    assert_receive {:info, "baz"}

    # handle_cast and terminate
    #
    TestActor.cast(actor, :foo)
    assert_receive {:cast, :foo}

    ref = Process.monitor(actor)
    Process.unlink(actor)
    TestActor.cast(actor, {:do_stop, :a_reason})

    assert_receive {:terminate, :a_reason}
    assert_receive {:DOWN, ^ref, _, _, :a_reason}
  end

  test "reconnecting" do
    test_pid = self()

    steps = [:ok, {:error, :econnrefused}, :ok]

    {:ok, history} = Adapter.Backdoor.start_history()
    {:ok, on_connect} = Adapter.Backdoor.on_connect(steps)

    default_genserver_timeout = 5000

    config = [adapter: Adapter,
              config:  [history: history, on_connect: on_connect],
              backoff: [default_genserver_timeout]] # simulate long reconnection

    {:ok, conn} = Hare.Conn.start_link(config)

    # init and connect
    {:ok, _actor} = TestActor.start_link(conn, test_pid)
    assert_receive {:connected, chan_1}

    # crash connection
    Adapter.Backdoor.crash(Hare.Conn.given_conn(conn), :normal)
    assert_receive {:disconnected, :normal}
    assert_receive {:connected, chan_2}, default_genserver_timeout * 2 + 100

    assert chan_1 != chan_2
  end
end
