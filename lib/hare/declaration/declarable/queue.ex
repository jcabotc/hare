defmodule Hare.Declaration.Declarable.Queue do
  @behaviour Hare.Declaration.Declarable

  alias Hare.Declaration.Declarable.Shared.NameAndOpts

  def validate(config) do
    NameAndOpts.validate(config)
  end

  def run(chan, config, _tags) do
    NameAndOpts.run(chan, :declare_queue, config)
  end
end
