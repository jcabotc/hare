defmodule Hare.Consumer.State do
  @moduledoc false

  alias __MODULE__

  defstruct [:declaration, :queue, :exchange,
             :mod, :given]

  def new(declaration, mod, given) do
    %State{declaration: declaration,
           mod:         mod,
           given:       given}
  end

  def declared(%State{} = state, queue, exchange),
    do: %{state | queue: queue, exchange: exchange}

  def set(%State{} = state, given),
    do: %{state | given: given}
end
