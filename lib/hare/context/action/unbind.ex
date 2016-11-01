defmodule Hare.Action.Unbind do
  @behaviour Hare.Action

  alias Hare.Action.Shared

  def validate(config) do
    Shared.Binding.validate(config)
  end

  def run(chan, config, tags) do
    Shared.Binding.run(chan, :unbind, config, tags)
  end
end
