defmodule Hare.Actor.RPC.Client.State do
  @moduledoc false

  alias __MODULE__

  defstruct [:declaration, :runtime_opts, :resp_queue, :req_exchange,
             :mod, :given,
             :waiting]

  def new(declaration, runtime_opts, mod, given) do
    %State{declaration:  declaration,
           runtime_opts: runtime_opts,
           mod:          mod,
           given:        given,
           waiting:      %{}}
  end

  def declared(%State{} = state, resp_queue, req_exchange) do
    %{state | resp_queue: resp_queue, req_exchange: req_exchange}
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
