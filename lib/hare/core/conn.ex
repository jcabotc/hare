defmodule Hare.Core.Conn do
  @moduledoc """
  The Hare connection.

  This module defines the connection process. It wraps the real
  AMQP connection and monitors it, handles failures and reconnections,
  and provides an interface to open new channels.
  """

  @type config :: State.Bridge.config

  use Connection

  alias __MODULE__.State

  @spec start_link(config, GenServer.options) :: GenServer.on_start
  def start_link(config, opts \\ []),
    do: Connection.start_link(__MODULE__, config, opts)

  @spec open_channel(conn :: pid) :: {:ok, Hare.Core.Chan} |
                                     {:error, reason :: term}
  def open_channel(conn),
    do: Connection.call(conn, :open_channel)

  def given_conn(conn),
    do: Connection.call(conn, :given_conn)

  def stop(conn, reason \\ :normal),
    do: Connection.call(conn, {:close, reason})

  def init(config) do
    state = State.new(config, &Connection.reply/2)

    {:connect, :init, state}
  end

  def connect(_info, state) do
    case State.connect(state) do
      {:ok, new_state}              -> {:ok, new_state}
      {:retry, interval, new_state} -> {:backoff, interval, new_state}
    end
  end

  def disconnect(reason, state),
    do: {:stop, reason, state}

  def handle_call(:open_channel, from, state),
    do: {:noreply, State.open_channel(state, from)}
  def handle_call({:close, reason}, _from, state),
    do: {:disconnect, reason, :ok, state}
  def handle_call(:given_conn, _from, state),
    do: {:reply, State.given_conn(state), state}

  def handle_info({:DOWN, ref, _, _, _reason}, state) do
    case State.down?(state, ref) do
      true  -> {:connect, :reconnect, state}
      false -> {:noreply, state}
    end
  end
  def handle_info(_anything, state) do
    {:noreply, state}
  end

  def terminate(_reason, state),
    do: State.disconnect(state)
end
