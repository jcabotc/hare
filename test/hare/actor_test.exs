defmodule Hare.ActorTest do
  use ExUnit.Case, async: true

  alias Hare.Actor

  defmodule FrontLayer do
    use Actor.Layer

    def channel(conn, _next, %{pid: pid} = state) do
      {:ok, chan} = Hare.Core.Chan.open(conn)

      send(pid, {:channel_front, chan})
      {:ok, chan, state}
    end

    def handle_call(:foo, _from, _next, state),
      do: {:reply, "FOO", state}
    def handle_call(_anything, _from, next, state),
      do: next.(state)

    def handle_info(message, next, %{pid: pid} = state) do
      send(pid, {:info_front, message})

      with {:noreply, ^pid} <- next.(pid),
        do: {:noreply, state}
    end
  end

  defmodule BackLayer do
    use Actor.Layer

    def init(_next, pid),
      do: {:ok, %{pid: pid}}

    def declare(chan, _next, %{pid: pid} = state) do
      send(pid, {:declare_back, chan})
      {:ok, state}
    end

    def handle_call(:bar, _from, _next, state),
      do: {:reply, "BAR", state}

    def handle_info(message, _next, pid) do
      send(pid, {:info_back, message})
      {:noreply, pid}
    end

    def terminate(_reason, _next, %{pid: pid}),
      do: send(pid, :terminate_back)
  end

  alias Hare.Adapter.Sandbox, as: Adapter

  test "everything" do
    {:ok, history} = Adapter.Backdoor.start_history()

    config = [adapter: Adapter,
              backoff: [0, 1000],
              config:  [history: history]]

    {:ok, conn} = Hare.Conn.start_link(config)

    test_pid     = self()
    given_layers = [FrontLayer]
    base_layers  = [BackLayer]
    opts         = [base_layers: base_layers]

    {:ok, actor} = Actor.start_link(given_layers, conn, test_pid, opts)
    assert_receive {:channel_front, chan_1}
    assert_receive {:declare_back,  ^chan_1}

    assert "FOO" == Actor.call(actor, :foo)
    assert "BAR" == Actor.call(actor, :bar)

    Adapter.Backdoor.crash(chan_1.given, :normal)
    assert_receive {:channel_front, chan_2}
    assert_receive {:declare_back,  ^chan_2}
    assert chan_1 != chan_2

    send(actor, "baz")
    assert_receive {:info_back, "baz"}
    assert_receive {:info_front, "baz"}

    ref = Process.monitor(actor)
    Process.unlink(actor)

    Actor.cast(actor, :qux)
    reason = {:no_more_layers, :handle_cast, [:qux, %{pid: test_pid}]}
    assert_receive {:DOWN, ^ref, _, _, ^reason}
  end
end
