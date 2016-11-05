defmodule Hare.Context.Action.Bind do
  @behaviour Hare.Context.Action

  alias Hare.Core.Queue
  alias Hare.Context.Action.Shared

  def validate(config) do
    Shared.Binding.validate(config)
  end

  def run(chan, config, exports) do
    binding_fun = &Queue.bind/3

    Shared.Binding.run(binding_fun, chan, config, exports)
  end
end
