defmodule Hare.Channel do
  alias __MODULE__

  defstruct [:given, :adapter]

  def new(given, adapter),
    do: %Channel{given: given, adapter: adapter}

  def monitor(%Channel{given: given, adapter: adapter}),
    do: adapter.monitor_channel(given)

  def link(%Channel{given: given, adapter: adapter}),
    do: adapter.link_channel(given)

  def unlink(%Channel{given: given, adapter: adapter}),
    do: adapter.unlink_channel(given)

  def close(%Channel{given: given, adapter: adapter}),
    do: adapter.close_channel(given)
end
