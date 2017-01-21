defmodule Hare.Publisher.State do
  alias __MODULE__

  defstruct [:conn, :declaration,
             :mod, :given,
             :chan, :ref, :exchange,
             :status]

  def new(conn, declaration, mod, given) do
    %State{mod:         mod,
           declaration: declaration,
           conn:        conn,
           given:       given,
           status:      :not_connected}
  end

  def connected(%State{} = state, chan, ref, exchange, new_given) do
    %{state | chan:     chan,
              ref:      ref,
              exchange: exchange,
              status:   :connected,
              given:    new_given}
  end

  def chan_down(%State{} = state) do
    %{state | chan:     nil,
              ref:      nil,
              exchange: nil,
              status:   :not_connected}
  end

  def set(%State{} = state, given) do
    %{state | given: given}
  end
end
