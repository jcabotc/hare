defmodule Hare.Core.Exchange do
  alias __MODULE__
  alias Hare.Core.Chan

  defstruct [:chan, :name]

  def default(%Chan{} = chan),
    do: %Exchange{chan: chan, name: ""}

  def new(%Chan{} = chan, name) when is_binary(name),
    do: %Exchange{chan: chan, name: name}

  def declare(%Chan{} = chan, name, type \\ :direct, opts \\ []) do
    %{given: given, adapter: adapter} = chan

    with :ok <- adapter.declare_exchange(given, name, type, opts) do
      {:ok, %Exchange{chan: chan, name: name}}
    end
  end

  def publish(exchange, payload, routing_key \\ "", opts \\ [])

  def publish(%Exchange{chan: chan, name: name}, payload, routing_key, opts)
  when is_binary(payload) and is_binary(routing_key) do
    %{given: given, adapter: adapter} = chan

    adapter.publish(given, name, payload, routing_key, opts)
  end

  def delete(%Exchange{chan: chan, name: name}, opts \\ []) do
    %{given: given, adapter: adapter} = chan

    adapter.delete_exchange(given, name, opts)
  end
end
