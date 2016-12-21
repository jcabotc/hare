defmodule Hare.RPC.Client.State do
  alias __MODULE__

  defstruct [:conn, :declaration,
             :mod, :given,
             :chan, :ref, :resp_queue, :req_exchange,
             :status, :waiting]

  def new(conn, declaration, mod, given) do
    %State{mod:         mod,
           declaration: declaration,
           conn:        conn,
           given:       given,
           waiting:     %{},
           status:      :not_connected}
  end

  def connected(%State{} = state, chan, ref, resp_queue, req_exchange) do
    %{state | chan:         chan,
              ref:          ref,
              resp_queue:   resp_queue,
              req_exchange: req_exchange,
              status:       :connected}
  end

  def chan_down(%State{} = state) do
    %{state | chan:         nil,
              ref:          nil,
              resp_queue:   nil,
              req_exchange: nil,
              status:       :not_connected}
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
