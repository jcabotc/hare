defmodule Hare.Adapter do
  @moduledoc """
  Specification of the AMQP adapter
  """

  @type t    :: module
  @type opts :: Keyword.t

  # Connection
  #
  @type conn :: term

  @doc "Establishes connection with the AMQP server using the given config."
  @callback open_connection(config :: term) ::
              {:ok, conn} | {:error, term}

  @doc "Monitors the process representing the AMQP connection."
  @callback monitor_connection(conn) ::
              reference

  @doc "Closes the AMQP connection."
  @callback close_connection(conn) ::
              :ok

  # Channel
  #
  @type chan :: term

  @doc "Opens a channel through the given connection"
  @callback open_channel(conn) ::
              {:ok, chan} | {:error, term}

  @doc "Monitors the process representing the channel"
  @callback monitor_channel(chan) ::
              reference

  @doc "Links the caller to the process representing the channel"
  @callback link_channel(chan) ::
              true

  @doc "Unlinks the caller to the process representing the channel"
  @callback unlink_channel(chan) ::
              true

  @doc "Sets the Quality Of Service of the channel"
  @callback qos(chan, opts) ::
              :ok

  @doc "Closes a channel"
  @callback close_channel(chan) ::
              :ok

  # Declare
  #
  @type exchange_name :: binary
  @type exchange_type :: atom

  @type queue_name :: binary

  @doc "Declares an exchange"
  @callback declare_exchange(chan, exchange_name, exchange_type, opts) ::
              :ok | {:error, reason :: term}

  @doc "Deletes an exchange"
  @callback delete_exchange(chan, exchange_name, opts) ::
              :ok

  @doc "Declares a queue"
  @callback declare_queue(chan, queue_name, opts) ::
              {:ok, info :: term} | {:error, term}

  @doc "Declares a server-named queue"
  @callback declare_server_named_queue(chan, opts) ::
              {:ok, queue_name, info :: term} | {:error, term}

  @doc "Deletes a queue"
  @callback delete_queue(chan, queue_name, opts) ::
              {:ok, info :: term}

  @doc "Binds a queue to an exchange"
  @callback bind(chan, queue_name, exchange_name, opts) ::
              :ok

  @doc "Unbinds a queue from an exchange"
  @callback unbind(chan, queue_name, exchange_name, opts) ::
              :ok

  # Publish
  #
  @type payload     :: binary
  @type routing_key :: binary

  @doc "Publishes a message to an exchange"
  @callback publish(chan, exchange_name, payload, routing_key, opts) ::
              :ok

  # Consume
  #
  @type meta         :: map
  @type consumer_tag :: binary

  @doc "Gets a message from a queue"
  @callback get(chan, queue_name, opts) ::
              {:empty, info :: map} | {:ok, payload, meta}

  @doc "Purges all messages in a queue"
  @callback purge(chan, queue_name) ::
              {:ok, info :: map}

  @doc """
  Consumes messages from a queue.

  Once a pid is consuming a queue status messages and actual queue messages
  must be sent to the consuming pid as elixir messages in a adapter-specific format.

  The function `handle/2` should receive that elixir messages and transform them into
  well defined terms.
  """
  @callback consume(chan, queue_name, pid, opts) ::
              {:ok, consumer_tag}

  @doc """
  Transforms a message received by a consumed pid into one of the well defined terms
  expected by consumers.

  The expected terms are:

    * `{:consume_ok, meta}` - `consume-ok` message sent by the AMQP server when a consumer is started
    * `{:deliver, payload, meta}` - an actual message from the queue being consumed
    * `{:cancel_ok, meta}` - `cancel-ok` message sent by the AMQP server when a consumer is started
    * `{:cancel, meta}` - `cancel` message sent by the AMQP server when a consumer has been unexpectedly closed
    * `:unknown` - any other message
  """
  @callback handle(message :: term) ::
              {:consume_ok, meta} |
              {:deliver, payload, meta} |
              {:cancel_ok, meta} |
              {:cancel, meta} |
              :unknown

  @doc "Cancels the consumer with the given consumer_tag"
  @callback cancel(chan, consumer_tag, opts) ::
              :ok

  @doc "Acks a message given its meta"
  @callback ack(chan, meta, opts) ::
              :ok

  @doc "Nacks a message given its meta"
  @callback nack(chan, meta, opts) ::
              :ok

  @doc "Rejects a message given its meta"
  @callback reject(chan, meta, opts) ::
              :ok
end
