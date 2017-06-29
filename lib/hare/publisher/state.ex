defmodule Hare.Publisher.State do
  @moduledoc false

  alias __MODULE__

  defstruct [:config,
             :declaration, :exchange, :connected,
             :mod, :given]

  def new(config, declaration, mod, given) do
    %State{config:      config,
           declaration: declaration,
           connected:   false,
           mod:         mod,
           given:       given}
  end

  def connected(%State{} = state, exchange),
    do: %{state | exchange: exchange, connected: true}

  def disconnected(%State{} = state),
    do: %{state | exchange: nil, connected: false}

  def set(%State{} = state, given),
    do: %{state | given: given}
end
