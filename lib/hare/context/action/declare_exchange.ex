defmodule Hare.Context.Action.DeclareExchange do
  @behaviour Hare.Context.Action

  alias Hare.Core.Exchange

  @default_type :direct
  @default_opts []

  import Hare.Context.Action.Helper.Validations,
    only: [validate: 3, validate: 4, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate(config, :name, :binary),
         :ok <- validate(config, :type, :atom, required: false),
         :ok <- validate_keyword(config, :opts, required: false),
         :ok <- validate(config, :export_as, :atom, required: false) do
      :ok
    end
  end

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
