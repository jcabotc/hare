defmodule Hare.Action.Bind do
  @behaviour Hare.Core.Action

  alias Hare.Action.Shared

  def validate(config) do
    Shared.Binding.validate(config)
  end

  def run(chan, config, tags) do
    Shared.Binding.run(chan, :bind, config, tags)
  end
end
