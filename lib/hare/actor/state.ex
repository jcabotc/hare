defmodule Hare.Actor.State do
  alias __MODULE__
  alias Hare.Core.Chan

  defstruct conn:   nil,
            chan:   nil,
            ref:    nil,
            status: :down,
            layers: [],
            given:  nil

  def new(conn, layers, given) when is_list(layers) do
    %State{conn: conn, layers: layers, given: given}
  end

  def set(%State{} = state, new_given) do
    %{state | given: new_given}
  end
  def set(%State{} = state, %Chan{} = chan, new_given) do
    ref = Chan.monitor(chan)

    %{state | chan:   chan,
              ref:    ref,
              status: :up,
              given:  new_given}
  end

  def down(%State{} = state) do
    %{state | chan: nil, ref: nil, status: :down}
  end

  def close(%State{status: :up, chan: chan}),
    do: Chan.close(chan)
  def close(%State{}),
    do: :ok
end
