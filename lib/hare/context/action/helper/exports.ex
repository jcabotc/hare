defmodule Hare.Context.Action.Helper.Exports do
  def get(exports, export) do
    case Map.fetch(exports, export) do
      {:ok, export} -> {:ok, export}
      :error     -> {:error, {:export_missing, export, exports}}
    end
  end

  def get_through(config, exports, field) do
    get(exports, Keyword.fetch!(config, field))
  end
end
