defmodule Hare.Core.Exchange do
  alias __MODULE__
  alias Hare.Core.Chan

  defstruct [:chan, :name]

  def new(%Chan{} = chan, name) when is_binary(name) do
    %Exchange{chan: chan, name: name}
  end

  def publish(exchange, payload, routing_key \\ "", opts \\ [])

  def publish(%Exchange{chan: chan, name: name}, payload, routing_key, opts)
  when is_binary(payload) and is_binary(routing_key) do
    %{given: given, adapter: adapter} = chan

    adapter.publish(given, name, payload, routing_key, opts)
  end
end
