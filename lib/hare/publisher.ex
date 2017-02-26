defmodule Hare.Publisher do
  @moduledoc """
  A wrapper of `Hare.Actor.Publisher`.

  Every macro and function of this module is delegated to `Hare.Actor.Publisher`.
  Check it for more information.
  """

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      use Hare.Actor.Publisher
    end
  end

  defdelegate start_link(mod, conn, config, initial),       to: Hare.Actor.Publisher
  defdelegate start_link(mod, conn, config, initial, opts), to: Hare.Actor.Publisher

  defdelegate publish(pid, payload),                    to: Hare.Actor.Publisher
  defdelegate publish(pid, payload, routing_key),       to: Hare.Actor.Publisher
  defdelegate publish(pid, payload, routing_key, opts), to: Hare.Actor.Publisher
end
