defmodule Hare.Context.Action.DeleteExchange do
  @moduledoc """
  This module implements a `Hare.Context.Action` behaviour to
  delete an exchange from the AMQP server.

  ## Config

  Configuration must be a `Keyword.t` with the following fields:

    * `:name` - the name of the exchange
    * `:opts` - (defaults to `[]`) the options to be given to the adapter
    * `:export_as` - (defaults to `nil`) the key to export the deleted exchange to

  The `:export_as` config allows the action to export a `Hare.Core.Exchange`
  struct to be used later by other steps (for example: to redeclare it with another type).

  ```
  alias Hare.Context.Action.DeleteExchange

  config = [name: "foo",
            opts: [no_wait: true],
            export_as: :deleted_ex]

  exports = %{}

  DeleteExchange.run(chan, config, exports)
  # => {:ok, nil, %{deleted_ex: %Hare.Core.Exchange{chan: chan, name: "foo"}}}
  ```
  """

  @typedoc "The action configuration"
  @type config :: %{required(:name) => binary,
                    optional(:opts) => Keyword.t,
                    optional(:export_as) => atom}

  @behaviour Hare.Context.Action

  alias Hare.Core.Exchange

  @default_opts []

  alias Hare.Core.Exchange
  alias Hare.Context.Action.Helper
  import Helper.Validations, only: [validate: 4, validate_keyword: 3]
  import Helper.Exports,     only: [validate_name_or_export: 3, get_name_or_export: 4]

  def validate(config) do
    with :ok <- validate_name_or_export(config, :name, :exchange_from_export),
         :ok <- validate_keyword(config, :opts, required: false),
         :ok <- validate(config, :export_as, :atom, required: false) do
      :ok
    end
  end

  def run(chan, config, exports) do
    with {:ok, exchange} <- get_exchange(chan, config, exports) do
      opts = Keyword.get(config, :opts, @default_opts)

      with :ok <- Exchange.delete(exchange, opts) do
        handle_exports(exchange, exports, config)
      end
    end
  end

  defp get_exchange(chan, config, exports) do
    case get_name_or_export(config, exports, :name, :exchange_from_export) do
      {:name, name}       -> {:ok, Exchange.new(chan, name)}
      {:export, exchange} -> {:ok, exchange}
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
