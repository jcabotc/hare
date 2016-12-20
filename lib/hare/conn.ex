defmodule Hare.Conn do
  defdelegate start_link(config),       to: Hare.Core.Conn
  defdelegate start_link(config, opts), to: Hare.Core.Conn
  defdelegate open_channel(conn),       to: Hare.Core.Conn
  defdelegate stop(conn),               to: Hare.Core.Conn
  defdelegate stop(conn, reason),       to: Hare.Core.Conn

  defdelegate given_conn(conn), to: Hare.Core.Conn
end
