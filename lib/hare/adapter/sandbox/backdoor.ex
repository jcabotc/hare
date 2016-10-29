defmodule Hare.Adapter.Sandbox.Backdoor do
  alias Hare.Adapter.Sandbox.Conn

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

  def crash(%Conn{} = conn, reason \\ :simulated_crash) do
    unlink(conn)
    Conn.stop(conn, reason)
  end
end
