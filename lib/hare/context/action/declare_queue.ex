defmodule Hare.Context.Action.DeclareQueue do
  @behaviour Hare.Context.Action

  alias Hare.Context.Action.Shared

  def validate(config) do
    Shared.NameAndOpts.validate(config)
  end

  def run(chan, config, _exports) do
    Shared.NameAndOpts.run(chan, :declare_queue, config)
  end
end
