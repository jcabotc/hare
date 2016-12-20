defmodule Hare.RPC.Client.State do
  alias __MODULE__

  defstruct [:conn, :declaration,
             :mod, :given,
             :chan, :ref, :req_queue, :resp_queue, :exchange,
             :status, :waiting]

  def new(conn, declaration, mod, given) do
    %State{mod:         mod,
           declaration: declaration,
           conn:        conn,
           given:       given,
           waiting:     %{},
           status:      :not_connected}
  end

  def connected(%State{} = state, chan, ref, req_queue, resp_queue, exchange) do
    %{state | chan:       chan,
              ref:        ref,
              req_queue:  req_queue,
              resp_queue: resp_queue,
              exchange:   exchange,
              status:     :connected}
  end

  def chan_down(%State{} = state) do
    %{state | chan:       nil,
              ref:        nil,
              req_queue:  nil,
              resp_queue: nil,
              exchange:   nil,
              status:     :not_connected}
  end

  def set(%State{} = state, given) do
    %{state | given: given}
  end

  def set(%State{waiting: waiting} = state, given, correlation_id, from) do
    new_waiting = Map.put(waiting, correlation_id, from)

    %{state | given: given, waiting: new_waiting}
  end

  def pop_waiting(%State{waiting: waiting} = state, correlation_id) do
    case Map.pop(waiting, correlation_id) do
      {nil, _}            -> :unknown
      {from, new_waiting} -> {:ok, from, %{state | waiting: new_waiting}}
    end
  end
end
