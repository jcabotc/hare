defmodule Hare.Adapter.Sandbox.Backdoor do
  alias Hare.Adapter.Sandbox.{Conn, Chan}

  def start_history(opts \\ []) do
    Conn.History.start_link(opts)
  end

  def on_connect(results, opts \\ []) do
    Conn.OnConnect.start_link(results, opts)
  end

  def events(history) do
    Conn.History.events(history)
  end

  def unlink(%Conn{} = conn) do
    Conn.unlink(conn)
  end
  def unlink(%Chan{} = chan) do
    Chan.unlink(chan)
  end

  def crash(resource, reason \\ :simulated_crash)

  def crash(%Conn{} = conn, reason) do
    Conn.stop(conn, reason)
  end
  def crash(%Chan{} = chan, reason) do
    Chan.stop(chan, reason)
  end
end
