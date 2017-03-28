defmodule Hare.Context.Action.DefaultExchange do
  @moduledoc """
  This module implements a `Hare.Context.Action` behaviour to
  build the default exchange.

  This action do not interact with the AMQP server, but provides an easy
  way to build the default exchange and export it, in order to be used by
  other steps or by the caller of the context.

  ## Config

  Configuration must be a `Keyword.t` with the following fields:

    * `:export_as` - (defaults to `nil`) the key to export the declared exchange to

  The `:export_as` config allows the action to export a `Hare.Core.Exchange`
  struct to be used later by other steps.

  ```
  alias Hare.Context.Action.DefaultExchange

  config  = [export_as: :def]
  exports = %{}

  DefaultExchange.run(chan, config, exports)
  # => {:ok, nil, %{def: %Hare.Core.Exchange{chan: chan, name: ""}}}
  ```
  """

  @typedoc "The action configuration"
  @type config :: [name:      binary,
                   type:      atom,
                   opts:      Keyword.t,
                   export_as: atom]
  @behaviour Hare.Context.Action

  alias Hare.Core.Exchange

  import Hare.Context.Action.Helper.Validations,
    only: [validate: 4]

  def validate(config) do
    validate(config, :export_as, :atom, required: false)
  end

  def run(chan, config, exports) do
    chan
    |> Exchange.default
    |> handle_exports(exports, config)
  end

  defp handle_exports(exchange, exports, config) do
    case Keyword.fetch(config, :export_as) do
      {:ok, export_tag} ->
        {:ok, nil, Map.put(exports, export_tag, exchange)}
      :error ->
        {:ok, nil}
    end
  end
end
