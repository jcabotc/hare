defmodule Hare.Declaration.Declarable.Unbind do
  @behaviour Hare.Declaration.Declarable

  alias Hare.Declaration.Declarable.Shared

  def validate(config) do
    Shared.Binding.validate(config)
  end

  def run(chan, config, tags) do
    Shared.Binding.run(chan, :unbind, config, tags)
  end
end
