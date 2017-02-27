defmodule Hare.Actor.Layer.Base do
  use Hare.Actor.Layer

  def init(_next, initial) do
    {:ok, initial}
  end

  def channel(conn, _next, state) do
    case Hare.Conn.open_channel(conn) do
      {:ok, chan} ->
        {:ok, chan, state}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  def declare(_chan, _next, state) do
    {:ok, state}
  end

  def handle_call(message, _from, _next, state) do
    {:stop, {:bad_call, message}, state}
  end

  def handle_cast(message, _next, state) do
    {:stop, {:bad_cast, message}, state}
  end

  def handle_info(_message, _next, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
