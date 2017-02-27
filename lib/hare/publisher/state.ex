defmodule Hare.Publisher.State do
  @moduledoc false

  alias __MODULE__

  defstruct [:config,
             :declaration, :exchange,
             :mod, :given]

  def new(config, declaration, mod, given) do
    %State{config:      config,
           declaration: declaration,
           mod:         mod,
           given:       given}
  end

  def declared(%State{} = state, exchange),
    do: %{state | exchange: exchange}

  def set(%State{} = state, given),
    do: %{state | given: given}
end
