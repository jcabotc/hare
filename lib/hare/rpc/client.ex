defmodule Hare.RPC.Client do
  @moduledoc """
  A wrapper of `Hare.Actor.RPC.Client`.

  Every macro and function of this module is delegated to `Hare.Actor.RPC.Client`.
  Check it for more information.
  """

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      use Hare.Actor.RPC.Client
    end
  end

  defdelegate start_link(mod, conn, config, initial),       to: Hare.Actor.RPC.Client
  defdelegate start_link(mod, conn, config, initial, opts), to: Hare.Actor.RPC.Client

  defdelegate request(client, payload),                             to: Hare.Actor.RPC.Client
  defdelegate request(client, payload, routing_key),                to: Hare.Actor.RPC.Client
  defdelegate request(client, payload, routing_key, opts),          to: Hare.Actor.RPC.Client
  defdelegate request(client, payload, routing_key, opts, timeout), to: Hare.Actor.RPC.Client
end
