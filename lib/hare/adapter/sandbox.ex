defmodule Hare.Adapter.Sandbox do
  @behaviour Hare.Adapter

  alias __MODULE__.{Conn, Chan}

  # Connection
  #
  def open_connection(config) do
    with {:ok, conn} = result <- Conn.open(config) do
      register(conn, {:open_connection, [config], result})
    end
  end

  def monitor_connection(conn) do
    result = Conn.monitor(conn)
    register(conn, {:monitor_connection, [conn], result})
  end

  def close_connection(conn) do
    result = Conn.stop(conn)
    register(conn, {:close_connection, [conn], result})
  end

  # Channel
  #
  def open_channel(conn) do
    result = Chan.open(conn)
    register(conn, {:open_channel, [conn], result})
  end

  def monitor_channel(chan) do
    result = Chan.monitor(chan)
    register(chan, {:monitor_channel, [chan], result})
  end

  def link_channel(chan) do
    result = Chan.link(chan)
    register(chan, {:link_channel, [chan], result})
  end

  def unlink_channel(chan) do
    result = Chan.unlink(chan)
    register(chan, {:unlink_channel, [chan], result})
  end

  def close_channel(chan) do
    result = Chan.close(chan)
    register(chan, {:close_channel, [chan], result})
  end

  # Helpers
  #
  defp register(%Conn{} = conn, event),
    do: Conn.register(conn, event)
  defp register(%Chan{} = conn, event),
    do: Chan.register(conn, event)
end
