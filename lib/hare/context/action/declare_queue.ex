defmodule Hare.Context.Action.DeclareQueue do
  @behaviour Hare.Context.Action

  alias Hare.Core.Queue

  @default_opts []

  import Hare.Context.Action.Helper.Validations,
    only: [validate: 3, validate: 4, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate(config, :name, :binary),
         :ok <- validate_keyword(config, :opts, required: false),
         :ok <- validate(config, :export_as, :atom, required: false) do
      :ok
    end
  end

  def run(chan, config, exports) do
    name = Keyword.fetch!(config, :name)
    opts = Keyword.get(config, :opts, @default_opts)

    with {:ok, info, queue} <- Queue.declare(chan, name, opts) do
      handle_exports(info, queue, exports, config)
    end
  end

  defp handle_exports(info, queue, exports, config) do
    case Keyword.fetch(config, :export_as) do
      {:ok, export_tag} ->
        {:ok, info, Map.put(exports, export_tag, queue)}
      :error ->
        {:ok, info}
    end
  end
end
