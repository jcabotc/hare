defmodule Hare.RPC.Server.State do
  @moduledoc false

  alias __MODULE__

  defstruct [:config,
             :declaration, :queue, :exchange,
             :mod, :given]

  def new(config, declaration, mod, given) do
    %State{config:      config,
           declaration: declaration,
           mod:         mod,
           given:       given}
  end

  def declared(%State{} = state, queue, exchange) do
    %{state | queue: queue, exchange: exchange}
  end

  def set(%State{} = state, given) do
    %{state | given: given}
  end
end
