defmodule Hare.Context.Action.Shared.Binding do
  @default_opts []

  alias Hare.Core.{Queue, Exchange}
  alias Hare.Context.Action.Helper
  import Helper.Validations, only: [validate_keyword: 3]
  import Helper.Exports,     only: [validate_name_or_export: 3, get_name_or_export: 4]

  def validate(config) do
    with :ok <- validate_name_or_export(config, :queue, :queue_from_export),
         :ok <- validate_name_or_export(config, :exchange, :exchange_from_export),
         :ok <- validate_keyword(config, :opts, required: false) do
      :ok
    end
  end

  def run(binding_fun, chan, config, exports) do
    with {:ok, queue}    <- get_queue(chan, config, exports),
         {:ok, exchange} <- get_exchange(chan, config, exports) do
      opts = Keyword.get(config, :opts, @default_opts)

      with {:ok, ^queue, ^exchange} <- binding_fun.(queue, exchange, opts) do
        handle_exports(queue, exchange, exports, config)
      end
    end
  end

  defp get_queue(chan, config, exports) do
    case get_name_or_export(config, exports, :queue, :queue_from_export) do
      {:name, name}    -> {:ok, Queue.new(chan, name)}
      {:export, queue} -> {:ok, queue}
    end
  end

  defp get_exchange(chan, config, exports) do
    case get_name_or_export(config, exports, :exchange, :exchange_from_export) do
      {:name, name}       -> {:ok, Exchange.new(chan, name)}
      {:export, exchange} -> {:ok, exchange}
    end
  end

  defp handle_exports(queue, exchange, exports, config) do
    case Keyword.fetch(config, :export_as) do
      {:ok, export_tag} ->
        {:ok, nil, Map.put(exports, export_tag, {queue, exchange})}
      :error ->
        {:ok, nil}
    end
  end
end
