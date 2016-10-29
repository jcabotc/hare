defmodule Hare.Adapter do
  @moduledoc """
  Specification of the AMQP adapter
  """

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

  @callback close_channel(chan) ::
              :ok
end
