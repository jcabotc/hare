defmodule Hare.Adapter.Sandbox.Chan do
  alias __MODULE__
  alias __MODULE__.Pid
  alias Hare.Adapter.Sandbox.Conn

  defstruct [:pid, :conn]

  def open(%Conn{} = conn) do
    case Conn.on_channel_open(conn) do
      :ok   -> {:ok, new(conn)}
      other -> other
    end
  end

  def monitor(%Chan{pid: pid}),
    do: Process.monitor(pid)

  def link(%Chan{pid: pid}),
    do: Process.link(pid)

  def unlink(%Chan{pid: pid}),
    do: Process.unlink(pid)

  def close(%Chan{pid: pid}, reason \\ :normal),
    do: Pid.stop(pid, reason)

  def register(%Chan{conn: conn}, event),
    do: Conn.register(conn, event)

  def get_message(%Chan{conn: conn}),
    do: Conn.get_message(conn)

  defp new(conn) do
    {:ok, pid} = Pid.start_link(fn -> Conn.monitor(conn) end)

    %Chan{pid: pid, conn: conn}
  end
end
