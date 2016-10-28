defmodule Hare.Adapter.Sandbox.Backdoor do
  alias Hare.Adapter.Sandbox.Conn

  def start_history(opts \\ []) do
    Conn.History.start_link(opts)
  end

  def events(history) do
    Conn.History.events(history)
  end
end
