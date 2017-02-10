defmodule Hare.Core.Exchange do
  @moduledoc """
  This module defines the `Hare.Core.Exchange` struct that represents
  an exchange and holds a channel to interact with it.
  """

  alias __MODULE__
  alias Hare.Core.Chan

  @type chan :: Chan.t
  @type name :: Hare.Adapter.exchange_name

  @type t :: %__MODULE__{
              chan: chan,
              name: name}

  @type type        :: Hare.Adapter.exchange_type
  @type opts        :: Hare.Adapter.opts
  @type payload     :: Hare.Adapter.payload
  @type routing_key :: Hare.Adapter.routing_key

  defstruct [:chan, :name]

  @doc """
  Builds the default exchange associated to the given channel.
  """
  @spec default(chan) :: t
  def default(%Chan{} = chan),
    do: %Exchange{chan: chan, name: ""}

  @doc """
  Builds an exchange with the given name associated to the given channel.

  The exchange is supposed to already be declared on the server in order
  to use it to run functions like `publish/4`.

  Is recommended to always use `declare/4` instead of `new/2` in order to
  ensure the exchange is already declared as expected before using it.
  """
  @spec new(chan, name) :: t
  def new(%Chan{} = chan, name) when is_binary(name),
    do: %Exchange{chan: chan, name: name}

  @doc """
  Declares an exchange on the AMQP server through the given channel, and
  builds an exchange struct associated to that channel.

  It expects the common exchange attributes that will be given to the
  underlying adapter:

    * `name` - The name of the exchange to declare
    * `type` - The type of the exchange as an atom (:fanout, :direct, etc)
    * `opts` - The exchange options
  """
  @spec declare(chan, name, type, opts) :: {:ok, t} |
                                           {:error, reason :: term}
  def declare(%Chan{} = chan, name, type \\ :direct, opts \\ [])
  when is_binary(name) and is_atom(type) do
    %{given: given, adapter: adapter} = chan

    with :ok <- adapter.declare_exchange(given, name, type, opts) do
      {:ok, %Exchange{chan: chan, name: name}}
    end
  end

  @doc """
  Publishes a message to the given exchange.

  It expects the following arguments:

    * `exchange` - The exchange (and its associated channel) to publish the message to
    * `payload` - The content of the message to be published
    * `routing_key` - The routing key
    * `opts` - The publish options that will be delegated directly to the adapter
  """
  @spec publish(t, payload, routing_key, opts) :: :ok
  def publish(exchange, payload, routing_key \\ "", opts \\ [])

  def publish(%Exchange{chan: chan, name: name}, payload, routing_key, opts)
  when is_binary(payload) and is_binary(routing_key) do
    %{given: given, adapter: adapter} = chan

    adapter.publish(given, name, payload, routing_key, opts)
  end

  @doc """
  It deletes the given exchange.

  It expects:

    * `exchange` - The exchange (and its associated channel) to delete
    * `opts` - The delete options that will be delegated directly to the adapter
  """
  @spec delete(t, opts) :: :ok
  def delete(%Exchange{chan: chan, name: name}, opts \\ []) do
    %{given: given, adapter: adapter} = chan

    adapter.delete_exchange(given, name, opts)
  end
end
