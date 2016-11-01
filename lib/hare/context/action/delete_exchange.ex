defmodule Hare.Action.DeleteExchange do
  @behaviour Hare.Action

  alias Hare.Action.Shared

  def validate(config) do
    Shared.NameAndOpts.validate(config)
  end

  def run(chan, config, _tags) do
    Shared.NameAndOpts.run(chan, :delete_exchange, config)
  end
end
