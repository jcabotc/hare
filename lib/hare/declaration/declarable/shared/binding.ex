defmodule Hare.Declaration.Declarable.Shared.Binding do
  @default_opts []

  alias Hare.Declaration.Declarable.Helper
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
         {:error, {:not_present, _, _}} <- validate(config, :queue_from_tag, :atom) do
      {:error, {:not_present, [:queue, :queue_from_tag], config}}
    end
  end

  def run(config, tags, binding) do
    with {:ok, queue} <- get_queue(config, tags) do
      exchange = Keyword.get(config, :exchange)
      opts     = Keyword.get(config, :opts, @default_opts)

      binding.(queue, exchange, opts)
    end
  end

  defp get_queue(config, tags) do
    with :error <- Keyword.fetch(config, :queue) do
      Helper.Tag.get_through(config, tags, :queue_from_tag)
    end
  end
end
