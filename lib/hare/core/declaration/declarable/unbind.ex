defmodule Hare.Core.Declaration.Declarable.Unbind do
  @behaviour Hare.Core.Declaration.Declarable

  alias Hare.Core.Declaration.Declarable.Shared

  def validate(config) do
    Shared.Binding.validate(config)
  end

  def run(chan, config, tags) do
    Shared.Binding.run(chan, :unbind, config, tags)
  end
end
