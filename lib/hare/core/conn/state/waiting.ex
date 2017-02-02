defmodule Hare.Core.Conn.State.Waiting do
  @moduledoc """
  This module defines the `Conn.State.Waiting` struct that keeps
  track of the clients waiting for a channel.

  Clients wait for a channel when they attempt to open a new one but
  the connection is not established.
  """

  alias __MODULE__

  @type client  :: GenServer.from
  @type clients :: [client]

  @type t :: %__MODULE__{
              clients: clients}

  defstruct [:clients]

  @doc """
  Builds a new Waiting struct.
  """
  @spec new() :: t
  def new,
    do: %Waiting{clients: []}

  @doc """
  Adds a new client to the list.
  """
  @spec push(t, client) :: t
  def push(%Waiting{clients: clients} = waiting, client),
    do: %{waiting | clients: [client | clients]}

  @doc """
  Pops all clients from the list.
  """
  @spec pop_all(t) :: {clients, t}
  def pop_all(%Waiting{clients: clients} = waiting),
    do: {clients, %{waiting | clients: []}}
end
