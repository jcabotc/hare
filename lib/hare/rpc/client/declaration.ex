defmodule Hare.RPC.Client.Declaration do
  @moduledoc false

  alias __MODULE__

  defstruct [:steps, :context]

  @response_queue_step {:declare_server_named_queue, [
                          export_as: :response_queue,
                          opts:      [auto_delete: true, exclusive: true]]}

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
    with {:ok, exchange_config} <- Keyword.fetch(config, :exchange),
         true                   <- Keyword.keyword?(exchange_config) do
      {:ok, build_steps(exchange_config)}
    else
      :error -> {:error, {:not_present, :exchange}}
      false  -> {:error, {:not_keyword_list, :exchange}}
    end
  end

  defp build_steps(exchange_config) do
    [@response_queue_step,
     declare_exchange: [{:export_as, :request_exchange} | exchange_config]]
  end

  def run(%Declaration{steps: steps, context: context}, chan) do
    with {:ok, result} <- context.run(chan, steps, validate: false) do
      %{request_exchange: request_exchange,
        response_queue:   response_queue} = result.exports

      {:ok, response_queue, request_exchange}
    end
  end
end
