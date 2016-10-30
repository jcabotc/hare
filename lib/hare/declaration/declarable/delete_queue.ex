defmodule Hare.Declaration.Declarable.DeleteQueue do
  @behaviour Hare.Declaration.Declarable

  alias Hare.Declaration.Declarable.Shared

  def validate(config) do
    Shared.NameAndOpts.validate(config)
  end

  def run(chan, config, _tags) do
    Shared.NameAndOpts.run(chan, :delete_queue, config)
  end
end
