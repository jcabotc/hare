defmodule Hare.Actor.State do
  alias __MODULE__
  alias Hare.Core.Chan

  defstruct [:conn,
             :chan, :ref,
             :mod, :given]

  def new(conn, mod, given)
  when is_atom(mod) do
    %State{conn: conn, mod: mod, given: given}
  end

  def set(%State{} = state, new_given) do
    %{state | given: new_given}
  end

  def up(%State{conn: conn} = state) do
    with {:ok, chan} <- Chan.open(conn) do
      ref = Chan.monitor(chan)
      new_state = %{state | chan: chan, ref: ref}

      {:ok, new_state}
    end
  end

  def crash(%State{} = state) do
    %{state | chan: nil, ref: nil}
  end

  def down(%State{chan: nil} = state) do
    state
  end
  def down(%State{chan: chan} = state) do
    Chan.close(chan)
    %{state | chan: nil, ref: nil}
  end
end
