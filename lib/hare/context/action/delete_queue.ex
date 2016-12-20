defmodule Hare.Context.Action.DeleteQueue do
  @behaviour Hare.Context.Action

  alias Hare.Core.Queue

  @default_opts []

  alias Hare.Core.Queue
  alias Hare.Context.Action.Helper
  import Helper.Validations, only: [validate: 4, validate_keyword: 3]
  import Helper.Exports,     only: [validate_name_or_export: 3, get_name_or_export: 4]

  def validate(config) do
    with :ok <- validate_name_or_export(config, :name, :queue_from_export),
         :ok <- validate_keyword(config, :opts, required: false),
         :ok <- validate(config, :export_as, :atom, required: false) do
      :ok
    end
  end

  def run(chan, config, exports) do
    with {:ok, queue} <- get_queue(chan, config, exports) do
      opts = Keyword.get(config, :opts, @default_opts)

      with {:ok, info} <- Queue.delete(queue, opts) do
        handle_exports(queue, info, exports, config)
      end
    end
  end

  defp get_queue(chan, config, exports) do
    case get_name_or_export(config, exports, :name, :queue_from_export) do
      {:name, name}    -> {:ok, Queue.new(chan, name)}
      {:export, queue} -> {:ok, queue}
    end
  end

  defp handle_exports(queue, info, exports, config) do
    case Keyword.fetch(config, :export_as) do
      {:ok, export_tag} ->
        {:ok, info, Map.put(exports, export_tag, queue)}
      :error ->
        {:ok, info}
    end
  end
end
