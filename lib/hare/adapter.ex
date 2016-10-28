defmodule Hare.Adapter do
  @type conn :: pid

  @callback connect(config :: term) ::
              {:ok, conn} | {:error, term}

  @callback disconnect(conn) ::
              :ok
end
