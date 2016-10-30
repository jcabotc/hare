defmodule Hare.Declaration.Declarable.Bind do
  @behaviour Hare.Declaration.Declarable

  alias Hare.Declaration.Declarable.Shared

  def validate(config) do
    Shared.Binding.validate(config)
  end

  def run(chan, config, tags) do
    Shared.Binding.run(config, tags, &action(chan, &1, &2, &3))
  end

  defp action(%{given: given, adapter: adapter}, queue, exchange, opts) do
    adapter.bind(given, queue, exchange, opts)
  end
end
