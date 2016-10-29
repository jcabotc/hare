defmodule Hare.Channel do
  alias __MODULE__

  defstruct [:given, :adapter]

  def new(given, adapter),
    do: %Channel{given: given, adapter: adapter}
end
