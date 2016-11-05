defmodule Hare.RPC.Server.Steps do
  def parse(config, context) do
    with {:ok, steps} <- steps(config),
         :ok          <- context.validate(steps) do
      {:ok, steps}
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
end
