defmodule Hare.Context.Action.DeclareExchange do
  @moduledoc """
  This module implements a `Hare.Context.Action` behaviour to
  declare an exchange on the AMQP server.

  ## Config

  Configuration must be a `Keyword.t` with the following fields:

    * `:name` - the name of the exchange
    * `:type` - (defaults to `:direct`) the type of the exchange
    * `:opts` - (defaults to `[]`) the options to be given to the adapter
    * `:export_as` - (defaults to `nil`) the key to export the declared exchange to

  The `:export_as` config allows the action to export a `Hare.Core.Exchange`
  struct to be used later by other steps (for example: to bind a queue to it)

  ```
  alias Hare.Context.Action.DeclareExchange

  config = [name: "foo",
            type: :fanout,
            opts: [durable: true],
            export_as: :ex]

  exports = %{}

  DeclareExchange.run(chan, config, exports)
  # => {:ok, nil, %{ex: %Hare.Core.Exchange{chan: chan, name: "foo"}}}
  ```
  """

  @typedoc "The action configuration"
  @type config :: %{required(:name)      => binary,
                    optional(:type)      => atom,
                    optional(:opts)      => Keyword.t,
                    optional(:export_as) => atom}

  @behaviour Hare.Context.Action

  alias Hare.Core.Exchange

  @default_type :direct
  @default_opts []

  import Hare.Context.Action.Helper.Validations,
    only: [validate: 3, validate: 4, validate_keyword: 3]

  @doc false
  def validate(config) do
    with :ok <- validate(config, :name, :binary),
         :ok <- validate(config, :type, :atom, required: false),
         :ok <- validate_keyword(config, :opts, required: false),
         :ok <- validate(config, :export_as, :atom, required: false) do
      :ok
    end
  end

  @doc false
  def run(chan, config, exports) do
    name = Keyword.fetch!(config, :name)
    type = Keyword.get(config, :type, @default_type)
    opts = Keyword.get(config, :opts, @default_opts)

    with {:ok, exchange} <- Exchange.declare(chan, name, type, opts) do
      handle_exports(exchange, exports, config)
    end
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
