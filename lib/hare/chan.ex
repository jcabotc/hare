defmodule Hare.Chan do
  alias __MODULE__

  defstruct [:given, :adapter]

  def new(given, adapter),
    do: %Chan{given: given, adapter: adapter}

  def monitor(%Chan{given: given, adapter: adapter}),
    do: adapter.monitor_channel(given)

  def link(%Chan{given: given, adapter: adapter}),
    do: adapter.link_channel(given)

  def unlink(%Chan{given: given, adapter: adapter}),
    do: adapter.unlink_channel(given)

  def close(%Chan{given: given, adapter: adapter}),
    do: adapter.close_channel(given)
end
