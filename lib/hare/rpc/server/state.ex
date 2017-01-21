defmodule Hare.RPC.Server.State do
  alias __MODULE__

  defstruct [:conn, :declaration,
             :mod, :given,
             :chan, :ref, :queue, :exchange,
             :status]

  def new(conn, declaration, mod, given) do
    %State{mod:         mod,
           declaration: declaration,
           conn:        conn,
           given:       given,
           status:      :not_connected}
  end

  def connected(%State{} = state, chan, ref, queue, exchange, given) do
    %{state | chan:     chan,
              ref:      ref,
              queue:    queue,
              exchange: exchange,
              given:    given,
              status:   :connected}
  end

  def chan_down(%State{} = state) do
    %{state | chan:     nil,
              ref:      nil,
              queue:    nil,
              exchange: nil,
              status:   :not_connected}
  end

  def set(%State{} = state, given),
    do: %{state | given: given}
end
