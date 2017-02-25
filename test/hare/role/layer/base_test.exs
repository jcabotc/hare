defmodule Hare.Role.Layer.BaseTest do
  use ExUnit.Case, async: true

  alias Hare.Role.Layer.Base
  alias Hare.Adapter.Sandbox, as: Adapter

  test "channel/3" do
    steps = [{:error, :a_reason}, :ok]
    {:ok, on_channel_open} = Adapter.Backdoor.on_channel_open(steps)

    config = [adapter: Adapter,
              backoff: [0, 1000],
              config:  [on_channel_open: on_channel_open]]

    {:ok, conn} = Hare.Conn.start_link(config)
    next        = &{:fake_next, &1}
    state       = :the_state

    assert {:stop, :a_reason, ^state}       = Base.channel(conn, next, state)
    assert {:ok, %Hare.Core.Chan{}, ^state} = Base.channel(conn, next, state)
  end

  test "rest" do
    message = "some_data"
    next    = &{:fake_next, &1}
    state   = :the_state

    expected = {:ok, state}
    assert expected == Base.init(next, state)
    assert expected == Base.declare(:chan, next, state)

    expected = {:stop, {:bad_call, message}, state}
    assert expected == Base.handle_call(message, :from, next, state)

    expected = {:stop, {:bad_cast, message}, state}
    assert expected == Base.handle_cast(message, next, state)

    expected = {:noreply, state}
    assert expected == Base.handle_info(message, next, state)

    expected = :ok
    assert expected == Base.terminate(:a_reason, state)
  end
end
