defmodule Hare.Conn.State.Waiting do
  alias __MODULE__

  defstruct [:clients]

  def new,
    do: %Waiting{clients: []}

  def push(%Waiting{clients: clients} = waiting, client),
    do: %{waiting | clients: [client | clients]}

  def pop_all(%Waiting{clients: clients} = waiting),
    do: {clients, %{waiting | clients: []}}
end
