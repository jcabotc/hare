defmodule Hare.Publisher.Declaration do
  @moduledoc false
  alias __MODULE__

  defstruct [:steps, :context]

  def parse(config, context) do
    with true         <- Keyword.keyword?(config),
         {:ok, steps} <- steps(config),
         :ok          <- context.validate(steps) do
      {:ok, %Declaration{steps: steps, context: context}}
    else
      false -> {:error, :not_keyword_list}
      error -> error
    end
  end

  defp steps(config) do
    with exchange_config <- Keyword.get(config, :exchange, []),
         true            <- Keyword.keyword?(exchange_config) do
      {:ok, build_steps(exchange_config)}
    else
      false  -> {:error, {:not_keyword_list, :exchange}}
    end
  end

  defp build_steps([]) do
    [default_exchange: [{:export_as, :exchange}]]
  end

  defp build_steps(exchange_config) do
    [declare_exchange: [{:export_as, :exchange} | exchange_config]]
  end

  def run(%Declaration{steps: steps, context: context}, chan) do
    with {:ok, result} <- context.run(chan, steps, validate: false) do
      %{exchange: exchange} = result.exports

      {:ok, exchange}
    end
  end
end
