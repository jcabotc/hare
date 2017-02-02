defmodule Hare.Core.Conn do
  @moduledoc """
  The Hare connection.

  This module defines the connection process. It wraps the real
  AMQP connection and monitors it, handles failures and reconnections,
  and provides an interface to open new channels.

  When the process has been started it tries to establish connection and,
  in case of failure, it keeps trying to reconnect forever.

  When a `open_channel/1` is called and the connection is not established
  it blocks the caller until the connection is established, after that it
  opens a channel and returns it.

  A timeout may be specified for this operation by using `open_channel/2`.
  By default the timeout is 5 seconds.
  """

  @type config :: State.Bridge.config

  use Connection

  alias __MODULE__.State

  @doc """
  Starts a `Hare.Core.Conn` process linked to the current process.

  It receives two arguments:

    * `config` - The bridge configuration. See `Hare.Core.Conn.State.Bridge` for more information
    * `opts` - GenServer options. See `GenServer.start_link/3` for more information.

  This function is used to start a `Hare.Core.Conn` on a supervision tree, and
  behaves like a GenServer.
  """
  @spec start_link(config, GenServer.options) :: GenServer.on_start
  def start_link(config, opts \\ []),
    do: Connection.start_link(__MODULE__, config, opts)

  @doc """
  Opens a new channel on the current connection.

  If the connection is already established it opens a channel and returns
  it inmediately.
  Otherwise, when the connection has not been established yet or it failed and
  it is reconnecting, the client will block until the connection is established
  to open the channel and return it.

  A timeout can be given to `GenServer.call/3`.
  """
  @spec open_channel(conn :: pid, timeout) :: {:ok, Hare.Core.Chan.t} |
                                              {:error, reason :: term}
  def open_channel(conn, timeout \\ 5000),
    do: Connection.call(conn, :open_channel, timeout)

  @doc """
  Returns the current AMQP connection given by the adapter.

  It is recommended to not use this function except for testing reasons.
  """
  @spec given_conn(conn :: pid) :: Hare.Adapter.conn
  def given_conn(conn),
    do: Connection.call(conn, :given_conn)

  @doc """
  Closes the current AMQP connection if open, and stops the `Hare.Core.Conn`
  process with the given reason (`:normal` by default).
  """
  @spec stop(conn :: pid, reason :: term) :: :ok
  def stop(conn, reason \\ :normal),
    do: Connection.call(conn, {:close, reason})

  @doc false
  def init(config) do
    state = State.new(config, &Connection.reply/2)

    {:connect, :init, state}
  end

  @doc false
  def connect(_info, state) do
    case State.connect(state) do
      {:ok, new_state}              -> {:ok, new_state}
      {:retry, interval, new_state} -> {:backoff, interval, new_state}
    end
  end

  @doc false
  def disconnect(reason, state),
    do: {:stop, reason, state}

  @doc false
  def handle_call(:open_channel, from, state),
    do: {:noreply, State.open_channel(state, from)}
  def handle_call({:close, reason}, _from, state),
    do: {:disconnect, reason, :ok, state}
  def handle_call(:given_conn, _from, state),
    do: {:reply, State.given_conn(state), state}

  @doc false
  def handle_info({:DOWN, ref, _, _, _reason}, state) do
    case State.down?(state, ref) do
      true  -> {:connect, :reconnect, state}
      false -> {:noreply, state}
    end
  end
  def handle_info(_anything, state) do
    {:noreply, state}
  end

  @doc false
  def terminate(_reason, state),
    do: State.disconnect(state)
end
