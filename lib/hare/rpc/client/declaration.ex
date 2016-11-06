defmodule Hare.RPC.Client.Declaration do
  alias __MODULE__

  defstruct [:steps, :context]

  @exchange_step {:default_exchange, [
                    export_as: :exchange]}

  @response_queue_step {:declare_server_named_queue, [
                          export_as: :response_queue,
                          opts:      [auto_delete: true, exclusive: true]]}

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
    [@exchange_step,
     @response_queue_step,
     declare_queue: [{:export_as, :request_queue} | queue_config]]
  end

  def run(%Declaration{steps: steps, context: context}, chan) do
    with {:ok, result} <- context.run(chan, steps, validate: false) do
      %{exchange:       exchange,
        response_queue: response_queue,
        request_queue:  request_queue} = result.exports

      {:ok, request_queue, response_queue, exchange}
    end
  end
end
