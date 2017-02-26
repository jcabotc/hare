defmodule Hare.RPC.Server do
  @moduledoc """
  A wrapper of `Hare.Actor.RPC.Server`.

  Every macro and function of this module is delegated to `Hare.Actor.RPC.Server`.
  Check it for more information.
  """

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      use Hare.Actor.RPC.Server
    end
  end

  defdelegate start_link(mod, conn, config, initial),       to: Hare.Actor.RPC.Server
  defdelegate start_link(mod, conn, config, initial, opts), to: Hare.Actor.RPC.Server

  defdelegate reply(meta, response), to: Hare.Actor.RPC.Server
end
