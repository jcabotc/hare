defmodule Hare.Adapter.Sandbox.Conn.Pid do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  def stop(pid, reason) do
    GenServer.cast(pid, {:stop, reason})
  end

  def handle_cast({:stop, reason}, state) do
    {:stop, reason, state}
  end
end
