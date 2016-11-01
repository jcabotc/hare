defmodule Hare.Context.Action.DeleteQueue do
  @behaviour Hare.Context.Action

  alias Hare.Context.Action.Shared

  def validate(config) do
    Shared.NameAndOpts.validate(config)
  end

  def run(chan, config, _exports) do
    Shared.NameAndOpts.run(chan, :delete_queue, config)
  end
end
