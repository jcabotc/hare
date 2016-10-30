defmodule Hare.Declaration.Declarable.Bind do
  @behaviour Hare.Declaration.Declarable

  @default_opts []

  import Hare.Declaration.Declarable.Helper.Validations,
    only: [validate: 3, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate_queue(config),
         :ok <- validate(config, :exchange, :binary),
         :ok <- validate_keyword(config, :opts, required: false) do
      :ok
    end
  end

  defp validate_queue(config) do
    with {:error, {:not_present, _, _}} <- validate(config, :queue, :binary),
         {:error, {:not_present, _, _}} <- validate(config, :queue_from_tag, :atom) do
      {:error, {:not_present, [:queue, :queue_from_tag], config}}
    end
  end

  def run(%{given: given, adapter: adapter}, config, tags) do
    with {:ok, queue} <- get_queue(config, tags) do
      exchange = Keyword.get(config, :exchange)
      opts     = Keyword.get(config, :opts, @default_opts)

      adapter.bind(given, queue, exchange, opts)
    end
  end

  defp get_queue(config, tags) do
    with :error <- Keyword.fetch(config, :queue) do
      get_queue_from_tag(config, tags)
    end
  end
  defp get_queue_from_tag(config, tags) do
    tag = Keyword.fetch!(config, :queue_from_tag)

    with :error <- Map.fetch(tags, tag) do
      {:error, {:tag_missing, tag, tags}}
    end
  end
end
