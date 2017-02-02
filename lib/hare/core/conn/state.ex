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

  If the connection is established it opens the channel and returns
  `{:ok, Hare.Core.Chan}` the new open channel on success or `{:error, reason}`
  on failure.
  If the connection is not established it returns `{:wait, t}` instructing the
  caller to hold the client and wait, because the reply function will be used
  to return the channel to the client when the connection is established.
  """
  @spec open_channel(t, client) :: {:ok, Hare.Chan.t} |
                                   {:wait, t} |
                                   {:error, reason :: term}
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

  defp handle_connect({:ok, new_bridge}, %{waiting: waiting, reply: reply} = state) do
    {clients, new_waiting} = Waiting.pop_all(waiting)
    reply_waiting(clients, new_bridge, reply)

    {:ok, %{state | bridge: new_bridge, waiting: new_waiting}}
  end
  defp handle_connect({:retry, interval, _reason, new_bridge}, state) do
    {:retry, interval, %{state | bridge: new_bridge}}
  end

  defp handle_open_channel({:ok, given_chan}, %{bridge: bridge}, _client) do
    {:ok, Chan.new(given_chan, bridge.adapter)}
  end
  defp handle_open_channel(:not_connected, %{waiting: waiting} = state, client) do
    {:wait, %{state | waiting: Waiting.push(waiting, client)}}
  end
  defp handle_open_channel({:error, _reason} = error, _state, _client) do
    error
  end

  defp reply_waiting(clients, bridge, reply) do
    Enum.each(clients, fn client ->
      result = Bridge.open_channel(bridge)
      reply.(client, result)
    end)
  end
end
