defmodule Hare.Core.Conn.State do
  @moduledoc """
  This module defines the `Conn.State` struct that holds the state of
  the `Conn` process.

  ## State fields

    * `bridge` - Keeps AMQP connection related state
    * `waiting` - Keeps clients waiting for a channel
    * `reply` - A function to reply to waiting clients with a channel

  ## Waiting clients

  When connection is established a channel is opened for each waiting
  client, and the reply function is called with the client and a channel.
  """

  alias __MODULE__
  alias __MODULE__.{Bridge, Waiting}
  alias Hare.Core.Chan

  @type reply :: (Waiting.client, Hare.Adapter.chan -> any)

  @type t :: %__MODULE__{
              bridge:  Bridge.t,
              waiting: Waiting.t,
              reply:   reply}

  defstruct [:bridge, :waiting, :reply]

  @type interval :: Bridge.interval
  @type client   :: Waiting.client

  @doc """
  Creates a new `Conn.State` struct.
  """
  @spec new(Bridge.config, reply) :: t
  def new(config, reply) do
    bridge  = Bridge.new(config)
    waiting = Waiting.new

    %State{bridge: bridge, waiting: waiting, reply: reply}
  end

  @doc """
  Establishes connection.

  On success replies to all waiting clients with a channel.
  On failure returns `{:retry, interval, state}` expecting the
  caller to wait for that interval before calling connect/1 again.
  """
  @spec connect(t) :: {:ok, t} |
                      {:retry, interval, t}
  def connect(%State{bridge: bridge} = state),
    do: Bridge.connect(bridge) |> handle_connect(state)

  @doc """
  It checks whether the given reference is the monitoring reference
  of the current established connection.
  """
  @spec down?(t, reference) :: boolean
  def down?(%State{bridge: bridge}, ref),
    do: bridge.ref == ref

  @doc """
  It attempts to open a new channel.

  If the connection is established, it uses the reply function to send the
  result to the client. `{:ok, Hare.Core.Chan.t}` on success and `{:error, reason}`
  on failure.

  If the connection is not established, it adds the client to the waiting list
  and tries to reopen the channel and reply when the connection is established.
  """
  @spec open_channel(t, client) :: t
  def open_channel(%State{bridge: bridge} = state, client),
    do: Bridge.open_channel(bridge) |> handle_open_channel(state, client)

  @doc """
  Returns the Bridge conn.
  """
  @spec given_conn(t) :: Hare.Adapter.conn
  def given_conn(%State{bridge: bridge}),
    do: Bridge.given_conn(bridge)

  @doc """
  Disconnects the bridge.
  """
  @spec disconnect(t) :: t
  def disconnect(%State{bridge: bridge} = state),
    do: %{state | bridge: Bridge.disconnect(bridge)}

  defp handle_connect({:ok, new_bridge}, %{waiting: waiting} = state) do
    {clients, new_waiting} = Waiting.pop_all(waiting)
    new_state = %{state | bridge: new_bridge, waiting: new_waiting}

    {:ok, reply_waiting(clients, new_state)}
  end
  defp handle_connect({:retry, interval, _reason, new_bridge}, state) do
    {:retry, interval, %{state | bridge: new_bridge}}
  end

  defp handle_open_channel({:ok, given_chan}, %{bridge: bridge, reply: reply} = state, client) do
    reply.(client, {:ok, Chan.new(given_chan, bridge.adapter)})
    state
  end
  defp handle_open_channel(:not_connected, %{waiting: waiting} = state, client) do
    %{state | waiting: Waiting.push(waiting, client)}
  end
  defp handle_open_channel({:error, _reason} = error, %{reply: reply} = state, client) do
    reply.(client, error)
    state
  end

  defp reply_waiting(clients, state),
    do: Enum.reduce(clients, state, &open_channel(&2, &1))
end
