defmodule Hare.Core.Chan do
  @moduledoc """
  This module defines the `Hare.Core.Chan` struct that represents
  an open channel and provides functions to interact with it.
  """

  alias __MODULE__

  @type t :: %__MODULE__{given:   Hare.Adapter.chan,
                         adapter: Hare.Adapter.t}

  defstruct [:given, :adapter]

  @doc """
  It opens a new connection on the given connection process.

  The connection process is expected to be a instance of the `Hare.Core.Conn`
  module.

  If the connection is not established, it blocks until it is established.
  A timeout in ms may be specified for this operation (5 seconds by default).
  """
  @spec open(conn :: pid, timeout) :: t
  def open(conn, timeout \\ 5000) do
    Hare.Core.Conn.open_channel(conn, timeout)
  end

  @doc """
  It buids a new `Hare.Core.Chan` struct from an adapter's channel representation
  and the adapter itself.

  This function is not meant to be called directly, but from a `Hare.Core.Conn`
  module.

  Use `open/1` to open new channels.
  """
  @spec new(Hare.Adapter.chan, Hare.Adapter.t) :: t
  def new(given, adapter),
    do: %Chan{given: given, adapter: adapter}

  @doc """
  Configures the Quality Of Service.

  It delegates the given options to the underlying adapter. The format
  of these options depends on the adapter.
  """
  @spec qos(t, Hare.Adapter.opts) :: :ok
  def qos(%Chan{given: given, adapter: adapter}, opts \\ []),
    do: adapter.qos(given, opts)

  @doc """
  Monitors the given channel process.
  """
  @spec monitor(t) :: reference
  def monitor(%Chan{given: given, adapter: adapter}),
    do: adapter.monitor_channel(given)

  @doc """
  Establishes a link with the given channel process.
  """
  @spec link(t) :: true
  def link(%Chan{given: given, adapter: adapter}),
    do: adapter.link_channel(given)

  @doc """
  Unlinks the given channel process fron the caller. If they are not linked
  it does nothing.
  """
  @spec unlink(t) :: true
  def unlink(%Chan{given: given, adapter: adapter}),
    do: adapter.unlink_channel(given)

  @doc """
  Closes the given channel.

  The channel should not be used after calling this function.
  """
  @spec close(t) :: :ok
  def close(%Chan{given: given, adapter: adapter}),
    do: adapter.close_channel(given)
end
