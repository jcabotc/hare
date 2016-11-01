defmodule Hare.Action.Queue do
  @behaviour Hare.Action

  alias Hare.Action.Shared

  def validate(config) do
    Shared.NameAndOpts.validate(config)
  end

  def run(chan, config, _tags) do
    Shared.NameAndOpts.run(chan, :declare_queue, config)
  end
end
