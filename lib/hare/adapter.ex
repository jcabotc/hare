defmodule Hare.Adapter do
  @type conn :: term

  @callback open_connection(config :: term) ::
              {:ok, conn} | {:error, term}

  @callback monitor_connection(conn) ::
              reference

  @callback link_connection(conn) ::
              true

  @callback close_connection(conn) ::
              :ok
end
