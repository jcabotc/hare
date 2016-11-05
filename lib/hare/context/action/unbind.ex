defmodule Hare.Context.Action.Unbind do
  @behaviour Hare.Context.Action

  alias Hare.Core.Queue
  alias Hare.Context.Action.Shared

  def validate(config) do
    Shared.Binding.validate(config)
  end

  def run(chan, config, exports) do
    binding_fun = &Queue.unbind/3

    Shared.Binding.run(binding_fun, chan, config, exports)
  end
end
