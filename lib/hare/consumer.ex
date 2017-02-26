defmodule Hare.Consumer do
  @moduledoc """
  A wrapper of `Hare.Actor.Consumer`.

  Every macro and function of this module is delegated to `Hare.Actor.Consumer`.
  Check it for more information.
  """

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      use Hare.Actor.Consumer
    end
  end

  defdelegate start_link(mod, conn, config, initial),             to: Hare.Actor.Consumer
  defdelegate start_link(mod, conn, config, initial, opts \\ []), to: Hare.Actor.Consumer

  defdelegate ack(meta),       to: Hare.Actor.Consumer
  defdelegate ack(meta, opts), to: Hare.Actor.Consumer

  defdelegate nack(meta),       to: Hare.Actor.Consumer
  defdelegate nack(meta, opts), to: Hare.Actor.Consumer

  defdelegate reject(meta),       to: Hare.Actor.Consumer
  defdelegate reject(meta, opts), to: Hare.Actor.Consumer
end
