defmodule Hare.Actor.State do
  alias __MODULE__
  alias Hare.Core.Chan

  defstruct [:conn, :status,
             :chan, :ref, :wait_ref,
             :mod, :given]

  def new(conn, mod, given)
  when is_atom(mod) do
    %State{conn: conn, mod: mod, given: given, status: :not_connected}
  end

  def set(%State{} = state, new_given) do
    %{state | given: new_given}
  end

  def open_channel(%State{conn: conn} = state) do
    conn
    |> Chan.open()
    |> handle_open_channel(state)
  end

  def request_channel(%State{conn: conn} = state) do
    %{ref: ref} = Task.async(Chan, :open, [conn, :infinity])
    %{state | wait_ref: ref}
  end

  def handle_open_channel({:ok, chan}, %State{} = state),
    do: {:ok, connected(state, chan)}
  def handle_open_channel({:error, reason}, %State{} = state),
    do: {:error, reason, crash(state)}

  def crash(%State{} = state) do
    %{state | chan: nil, ref: nil, wait_ref: nil, status: :not_connected}
  end

  def down(%State{chan: nil} = state) do
    state
  end
  def down(%State{chan: chan} = state) do
    Chan.close(chan)
    %{state | chan: nil, ref: nil, status: :not_connected}
  end

  defp connected(state, chan) do
    ref = Chan.monitor(chan)
    %{state | chan: chan, ref: ref, wait_ref: nil, status: :connected}
  end
end
