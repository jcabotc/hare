defmodule Hare.Core.Declaration.Declarable.DeleteExchange do
  @behaviour Hare.Core.Declaration.Declarable

  alias Hare.Core.Declaration.Declarable.Shared

  def validate(config) do
    Shared.NameAndOpts.validate(config)
  end

  def run(chan, config, _tags) do
    Shared.NameAndOpts.run(chan, :delete_exchange, config)
  end
end
