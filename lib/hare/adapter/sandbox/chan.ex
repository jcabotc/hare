defmodule Hare.Adapter.Sandbox.Chan do
  alias __MODULE__
  alias __MODULE__.Pid
  alias Hare.Adapter.Sandbox.Conn

  defstruct [:pid, :conn]

  def open(%Conn{} = conn) do
    {:ok, pid} = new_pid(conn)

    {:ok, %Chan{pid: pid, conn: conn}}
  end

  def monitor(%Chan{pid: pid}) do
    Process.monitor(pid)
  end

  def link(%Chan{pid: pid}) do
    Process.link(pid)
  end

  def unlink(%Chan{pid: pid}) do
    Process.unlink(pid)
  end

  def stop(%Chan{pid: pid}, reason \\ :normal) do
    Pid.stop(pid, reason)
  end

  def register(%Chan{conn: conn}, event) do
    Conn.register(conn, event)
  end

  defp new_pid(conn) do
    Pid.start_link fn ->
      Conn.monitor(conn)
    end
  end
end
