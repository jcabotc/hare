defmodule Hare.Consumer.Declaration do
  @moduledoc false

  alias __MODULE__

  defstruct [:steps, :context]

  @bind_exported_resources [exchange_from_export: :exchange,
                            queue_from_export:    :queue]

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
      binds_opts = get_binds(config)
      qos_opts = Keyword.get(config, :qos)

      {:ok, build_steps(exchange_config, queue_config, binds_opts, qos_opts)}
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

  def get_binds(config) do
    with [] <- Keyword.get_values(config, :bind),
      do: [[]]
  end

  defp build_steps(exchange_config, queue_config, binds_opts, qos_opts) do
    resources = [declare_exchange: [{:export_as, :exchange} | exchange_config],
                 declare_queue:    [{:export_as, :queue}    | queue_config]]

    binds = Enum.map binds_opts, fn (bind_opts) ->
      {:bind, [{:opts, bind_opts} | @bind_exported_resources]}
    end

    qos = if qos_opts, do: [qos: qos_opts], else: []

    resources ++ binds ++ qos
  end

  def run(%Declaration{steps: steps, context: context}, chan) do
    with {:ok, result} <- context.run(chan, steps, validate: false) do
      %{queue: queue, exchange: exchange} = result.exports

      {:ok, queue, exchange}
    end
  end
end
