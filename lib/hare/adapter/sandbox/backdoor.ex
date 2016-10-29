defmodule Hare.Adapter.Sandbox.Backdoor do
  alias Hare.Adapter.Sandbox.{Conn, Chan}

  def start_history(opts \\ []),
    do: Conn.History.start_link(opts)

  def on_connect(results, opts \\ []),
    do: Conn.Stack.start_link(results, opts)
  def on_channel_open(results, opts \\ []),
    do: Conn.Stack.start_link(results, opts)

  def events(history),
    do: Conn.History.events(history)

  def unlink(%Conn{} = conn),
    do: Conn.unlink(conn)
  def unlink(%Chan{} = chan),
    do: Chan.unlink(chan)

  def crash(resource, reason \\ :simulated_crash)

  def crash(%Conn{} = conn, reason),
    do: Conn.stop(conn, reason)
  def crash(%Chan{} = chan, reason),
    do: Chan.close(chan, reason)
end
