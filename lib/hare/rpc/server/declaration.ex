defmodule Hare.RPC.Server.Declaration do
  @moduledoc false

  alias __MODULE__

  defstruct [:steps, :context]

  @response_exchange_step {:default_exchange, [
                             export_as: :response_exchange]}

  @bind_exported_resources [exchange_from_export: :request_exchange,
                            queue_from_export:    :request_queue]

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
    with {:ok, exchange_config} <- extract(config, :exchange),
         {:ok, queue_config}    <- extract(config, :queue) do
      bind_opts = Keyword.get(config, :bind, [])

      {:ok, build_steps(exchange_config, queue_config, bind_opts)}
    end
  end

  defp extract(config, key) do
    with {:ok, extracted_config} <- Keyword.fetch(config, key),
         true                    <- Keyword.keyword?(extracted_config) do
      {:ok, extracted_config}
    else
      :error -> {:error, {:not_present, key}}
      false  -> {:error, {:not_keyword_list, key}}
    end
  end

  defp build_steps(exchange_config, queue_config, bind_opts) do
    [@response_exchange_step,
     declare_exchange: [{:export_as, :request_exchange} | exchange_config],
     declare_queue:    [{:export_as, :request_queue}    | queue_config],
     bind:             [{:opts, bind_opts} | @bind_exported_resources]]
  end

  def run(%Declaration{steps: steps, context: context}, chan) do
    with {:ok, result} <- context.run(chan, steps, validate: false) do
      %{request_queue:     request_queue,
        response_exchange: response_exchange} = result.exports

      {:ok, request_queue, response_exchange}
    end
  end
end
