defmodule Hare.Context.Action.Helper.Exports do
  import Hare.Context.Action.Helper.Validations,
    only: [validate: 3]

  def get(exports, export) do
    case Map.fetch(exports, export) do
      {:ok, export} -> {:ok, export}
      :error        -> {:error, {:export_missing, export, exports}}
    end
  end

  def get_through(config, exports, field) do
    get(exports, Keyword.fetch!(config, field))
  end

  def validate_name_or_export(config, name_field, export_field) do
    with {:error, {:not_present, _, _}} <- validate(config, name_field, :binary),
         {:error, {:not_present, _, _}} <- validate(config, export_field, :atom) do
      {:error, {:not_present, [name_field, export_field], config}}
    end
  end

  def get_name_or_export(config, exports, name_field, export_field) do
    case Keyword.fetch(config, name_field) do
      {:ok, name} -> {:name, name}
      :error      -> try_export(config, exports, export_field)
    end
  end
  defp try_export(config, exports, field) do
    with {:ok, export} <- get_through(config, exports, field) do
      {:export, export}
    end
  end
end
