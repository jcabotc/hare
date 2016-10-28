defmodule Hare.Adapter.Sandbox do
  @behaviour Hare.Adapter

  alias __MODULE__.Conn

  def open_connection(config) do
    with {:ok, conn} = result <- Conn.open(config) do
      register(conn, {:open_connection, [config], result})
    end
  end

  def monitor_connection(conn) do
    result = Conn.monitor(conn)
    register(conn, {:monitor_connection, [conn], result})
  end

  def link_connection(conn) do
    result = Conn.link(conn)
    register(conn, {:link_connection, [conn], result})
  end

  def close_connection(conn) do
    result = Conn.stop(conn)
    register(conn, {:close_connection, [conn], result})
  end

  defp register(conn, event) do
    Conn.register(conn, event)
  end
end
