defmodule Hare.Context.Action.Unbind do
  @behaviour Hare.Context.Action

  alias Hare.Context.Action.Shared

  def validate(config) do
    Shared.Binding.validate(config)
  end

  def run(chan, config, exports) do
    Shared.Binding.run(chan, :unbind, config, exports)
  end
end
