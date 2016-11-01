defmodule Hare.Context.Action.Shared.Binding do
  @default_opts []

  alias Hare.Context.Action.Helper
  import Helper.Validations, only: [validate: 3, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate_queue(config),
         :ok <- validate(config, :exchange, :binary),
         :ok <- validate_keyword(config, :opts, required: false) do
      :ok
    end
  end

  defp validate_queue(config) do
    with {:error, {:not_present, _, _}} <- validate(config, :queue, :binary),
         {:error, {:not_present, _, _}} <- validate(config, :queue_from_export, :atom) do
      {:error, {:not_present, [:queue, :queue_from_export], config}}
    end
  end

  def run(%{given: given, adapter: adapter}, action, config, exports) do
    with {:ok, queue} <- get_queue(config, exports) do
      exchange = Keyword.get(config, :exchange)
      opts     = Keyword.get(config, :opts, @default_opts)

      apply(adapter, action, [given, queue, exchange, opts])
    end
  end

  defp get_queue(config, exports) do
    with :error <- Keyword.fetch(config, :queue) do
      Helper.Exports.get_through(config, exports, :queue_from_export)
    end
  end
end
