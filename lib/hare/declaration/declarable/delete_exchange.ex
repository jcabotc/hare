defmodule Hare.Declaration.Declarable.DeleteExchange do
  @behaviour Hare.Declaration.Declarable

  alias Hare.Declaration.Declarable.Shared.NameAndOpts

  def validate(config) do
    NameAndOpts.validate(config)
  end

  def run(chan, config, _tags) do
    NameAndOpts.run(chan, :delete_exchange, config)
  end
end
