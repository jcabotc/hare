defmodule Hare.Queue do
  alias __MODULE__
  alias Hare.Chan

  defstruct chan: nil,
            name: nil

  def new(%Chan{} = chan, name) when is_binary(name) do
    %Queue{chan: chan, name: name}
  end

  def get(%Queue{chan: chan, name: name}, opts \\ []) do
    %{given: given, adapter: adapter} = chan

    adapter.get(given, name, opts)
  end
end
