defmodule Hare.Core.Conn.State.Bridge do
  @moduledoc """
  This module defines the `Conn.State.Bridge` struct that keeps
  the state and configuration of the AMQP connection, and the main
  functions for working with it.

  ## Bridge fields

  Adapter fields:

    * `adapter` - the adapter to the underlying AMQP library
    * `config` - the configuration to be given to the adapter when opening connection

  Retrying failed connection fields:

    * `backoff` - a list of time intervals (in ms) to wait to retry a failed connection
    * `next_intervals` - the list of remaining backoff intervals for the current retrying process

  Information regarding the current active connection:

    * `given` - the term given by the AMQP adapter representing a connection
    * `ref` - the monitoring reference for the connection
    * `status` - the current connection status (:not_connected | :connected | :reconnecting)

  ## Backoff and failed connections

  When the connect/1 function is called and the AMQP adapter fails to establish connection
  the status is set to :reconnecting and it `{:retry, backoff_interval, reason, new_state}`.
  When connect/1 is called again and it fails again the same response is given with the next
  backoff interval.
  When all but one backoff intervals have been returned, the last one is returned forever.
  """

  @type adapter        :: Hare.Adapter.t
  @type adapter_config :: term
  @type interval       :: non_neg_integer
  @type backoff        :: [interval]
  @type given          :: Hare.Adapter.conn
  @type status         :: :not_connected | :connected | :reconnecting

  @type t :: %__MODULE__{
              adapter:        adapter,
              config:         adapter_config,
              backoff:        backoff,
              next_intervals: backoff,
              given:          given,
              ref:            reference,
              status:         status}

  defstruct [:adapter, :config,
             :backoff, :next_intervals,
             :given, :ref, :status]

  @type config_option :: {:adapter, adapter} |
                         {:backoff, backoff} |
                         {:config,  adapter_config}

  @type config :: [config_option]

  alias __MODULE__

  @doc """
  Creates a new Bridge struct.

  It expect the given config to contain the following fields:

    * `:adapter` - the AMQP adapter to use
    * `:backoff` - the list of backoff intervals
    * `:config` - the AMQP adapter config to use when establishing connection
  """
  @spec new(config) :: t
  def new(config) do
    adapter      = Keyword.fetch!(config, :adapter)
    backoff      = Keyword.fetch!(config, :backoff)
    given_config = Keyword.fetch!(config, :config)

    %Bridge{adapter: adapter, backoff: backoff, config: given_config}
    |> set_not_connected
  end

  @doc """
  Establishes connection through the AMQP adapter.

  On success it returns `{:ok, bridge}`.
  On failure it returns `{:retry, interval, reason, bridge}` and expects
  the caller to wait that interval before calling `connect/1` again.
  """
  @spec connect(t) :: {:ok, t} |
                      {:retry, interval, reason :: term, t}
  def connect(%Bridge{adapter: adapter, config: config} = bridge) do
    config
    |> adapter.open_connection
    |> handle_connect(bridge)
  end

  @doc """
  Opens a new channel on the active connection.

  When the status is :connected, it returns the adapter's `open_channel/1`
  result, otherwise it returns `:not_connected`.
  """
  @spec open_channel(t) :: {:ok, Hare.Adapter.chan} |
                           {:error, reason :: term} |
                           :not_connected
  def open_channel(%Bridge{adapter: adapter, given: given, status: :connected}),
    do: adapter.open_channel(given)
  def open_channel(%Bridge{}),
    do: :not_connected

  @doc """
  Returns the current AMQP adapter connection term.
  """
  @spec given_conn(t) :: Hare.Adapter.conn
  def given_conn(%Bridge{given: given}) do
    given
  end

  @doc """
  Disconnects the current connection.

  If connected it disconnects, otherwise it does nothing.
  """
  @spec disconnect(t) :: t
  def disconnect(%Bridge{adapter: adapter, given: given, status: :connected} = bridge) do
    adapter.close_connection(given)
    set_not_connected(bridge)
  end
  def disconnect(%Bridge{} = bridge) do
    set_not_connected(bridge)
  end

  defp handle_connect({:ok, given}, %{adapter: adapter} = bridge) do
    ref = adapter.monitor_connection(given)
    {:ok, set_connected(bridge, given, ref)}
  end
  defp handle_connect({:error, reason}, %{status: :reconnecting} = bridge) do
    {interval, new_state} = pop_interval(bridge)
    {:retry, interval, reason, new_state}
  end
  defp handle_connect(error, bridge) do
    handle_connect(error, set_reconnecting(bridge))
  end

  defp pop_interval(%{next_intervals: [last]} = bridge),
    do: {last, bridge}
  defp pop_interval(%{next_intervals: [next | rest]} = bridge),
    do: {next, %{bridge | next_intervals: rest}}

  defp set_connected(bridge, given, ref),
    do: %{bridge | status: :connected, given: given, ref: ref}
  defp set_reconnecting(%{backoff: backoff} = bridge),
    do: %{bridge | status: :reconnecting, given: nil, ref: nil, next_intervals: backoff}
  defp set_not_connected(bridge),
    do: %{bridge | status: :not_connected, given: nil, ref: nil}
end
