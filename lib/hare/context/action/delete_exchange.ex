defmodule Hare.Context.Action.DeleteExchange do
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
