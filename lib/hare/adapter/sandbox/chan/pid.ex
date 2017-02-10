defmodule Hare.Adapter.Sandbox.Chan.Pid do
  @moduledoc false

  use GenServer

  def start_link(monitor_conn),
    do: GenServer.start_link(__MODULE__, monitor_conn)

  def start(monitor_conn),
    do: GenServer.start(__MODULE__, monitor_conn)

  def stop(pid, reason),
    do: GenServer.cast(pid, {:stop, reason})

  def init(monitor_conn) do
    ref = monitor_conn.()

    {:ok, %{ref: ref}}
  end

  def handle_cast({:stop, reason}, state) do
    {:stop, reason, state}
  end

  def handle_info({:DOWN, ref, _, _, reason}, %{ref: ref} = state) do
    {:stop, reason, state}
  end
  def handle_info(_anything, state) do
    {:noreply, state}
  end
end
