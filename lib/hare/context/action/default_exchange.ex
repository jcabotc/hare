defmodule Hare.Context.Action.DefaultExchange do
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
