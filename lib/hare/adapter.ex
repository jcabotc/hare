defmodule Hare.Adapter do
  @moduledoc """
  Specification of the AMQP adapter
  """

  @type t    :: module
  @type opts :: Keyword.t

  # Connection
  #
  @type conn :: term

  @callback open_connection(config :: term) ::
              {:ok, conn} | {:error, term}

  @callback monitor_connection(conn) ::
              reference

  @callback close_connection(conn) ::
              :ok

  # Channel
  #
  @type chan :: term

  @callback open_channel(conn) ::
              {:ok, chan} | {:error, term}

  @callback monitor_channel(chan) ::
              reference

  @callback link_channel(chan) ::
              true

  @callback unlink_channel(chan) ::
              true

  @callback qos(chan, opts) ::
              :ok

  @callback close_channel(chan) ::
              :ok

  # Declare
  #
  @type exchange_name :: binary
  @type exchange_type :: atom

  @type queue_name :: binary

  @callback declare_exchange(chan, exchange_name, exchange_type, opts) ::
              :ok | {:error, reason :: term}

  @callback delete_exchange(chan, exchange_name, opts) ::
              :ok

  @callback declare_queue(chan, queue_name, opts) ::
              {:ok, info :: term} | {:error, term}

  @callback declare_server_named_queue(chan, opts) ::
              {:ok, queue_name, info :: term} | {:error, term}

  @callback delete_queue(chan, queue_name, opts) ::
              {:ok, info :: term}

  @callback bind(chan, queue_name, exchange_name, opts) ::
              :ok

  @callback unbind(chan, queue_name, exchange_name, opts) ::
              :ok

  # Publish
  #
  @type payload     :: binary
  @type routing_key :: binary

  @callback publish(chan, exchange_name, payload, routing_key, opts) ::
              :ok

  # Consume
  #
  @type meta         :: map
  @type consumer_tag :: binary

  @callback get(chan, queue_name, opts) ::
              {:empty, info :: map} | {:ok, payload, meta}

  @callback purge(chan, queue_name) ::
              {:ok, info :: map}

  @callback consume(chan, queue_name, pid, opts) ::
              {:ok, consumer_tag}

  @callback handle(message :: term) ::
              {:consume_ok, meta} |
              {:deliver, payload, meta} |
              {:cancel_ok, meta} |
              :unknown

  @callback cancel(chan, consumer_tag, opts) ::
              :ok

  @callback ack(chan, meta, opts) ::
              :ok

  @callback nack(chan, meta, opts) ::
              :ok

  @callback reject(chan, meta, opts) ::
              :ok
end
