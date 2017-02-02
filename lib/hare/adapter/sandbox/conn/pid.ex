defmodule Hare.Adapter.Sandbox.Conn.Pid do
  @moduledoc false

  use GenServer

  def start_link,
    do: GenServer.start_link(__MODULE__, :ok)

  def stop(pid, reason),
    do: GenServer.cast(pid, {:stop, reason})

  def handle_cast({:stop, reason}, state),
    do: {:stop, reason, state}
end
