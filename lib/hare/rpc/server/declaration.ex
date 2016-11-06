defmodule Hare.RPC.Server.Declaration do
  alias __MODULE__

  defstruct [:steps, :context]

  def parse(config, context) do
    with {:ok, steps} <- steps(config),
         :ok          <- context.validate(steps) do
      {:ok, %Declaration{steps: steps, context: context}}
    end
  end

  defp steps(config) do
    with {:ok, queue_config} <- Keyword.fetch(config, :queue),
         true                <- Keyword.keyword?(queue_config) do
      {:ok, build_steps(queue_config)}
    else
      :error -> {:error, {:not_present, :queue}}
      false  -> {:error, {:not_keyword_list, :queue}}
    end
  end

  defp build_steps(queue_config) do
    [default_exchange: [export_as: :exchange],
     declare_queue:    [{:export_as, :queue} | queue_config]]
  end

  def run(%Declaration{steps: steps, context: context}, chan) do
    with {:ok, result} <- context.run(chan, steps, validate: false) do
      %{queue: queue, exchange: exchange} = result.exports

      {:ok, queue, exchange}
    end
  end
end
