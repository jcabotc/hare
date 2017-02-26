defmodule Hare.Actor.Publisher.State do
  @moduledoc false

  alias __MODULE__

  defstruct [:declaration, :exchange,
             :mod, :given]

  def new(declaration, mod, given) do
    %State{declaration: declaration,
           mod:         mod,
           given:       given}
  end

  def declared(%State{} = state, exchange),
    do: %{state | exchange: exchange}

  def set(%State{} = state, given),
    do: %{state | given: given}
end
