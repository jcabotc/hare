defmodule Hare.RPC.Client.State do
  @moduledoc false

  alias __MODULE__

  defstruct [:config,
             :declaration, :runtime_opts, :chan, :resp_queue, :req_exchange,
             :mod, :given,
             :connected, :waiting]

  def new(config, declaration, runtime_opts, mod, given) do
    %State{config:       config,
           declaration:  declaration,
           runtime_opts: runtime_opts,
           mod:          mod,
           given:        given,
           connected:    false,
           waiting:      %{}}
  end

  def connected(%State{} = state, chan, resp_queue, req_exchange) do
    %{state | chan: chan, resp_queue: resp_queue, req_exchange: req_exchange, connected: true}
  end

  def set(%State{} = state, given) do
    %{state | given: given}
  end

  def set(%State{waiting: waiting} = state, given, correlation_id, from) do
    new_waiting = Map.put(waiting, correlation_id, from)

    %{state | given: given, waiting: new_waiting}
  end

  def disconnected(%State{} = state) do
    %{state | chan: nil, resp_queue: nil, req_exchange: nil, connected: false}
  end

  def pop_waiting(%State{waiting: waiting} = state, correlation_id) do
    case Map.pop(waiting, correlation_id) do
      {nil, _}            -> :unknown
      {from, new_waiting} -> {:ok, from, %{state | waiting: new_waiting}}
    end
  end

  def clear_waiting(%State{waiting: waiting} = state, func) when is_function(func) do
    waiting
    |> Map.values()
    |> Enum.each(func)

    %{state | waiting: %{}}
  end
end
