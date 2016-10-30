defmodule Hare.Declaration.Declarable do
  @type config :: Keyword.t

  @callback validate(config) ::
              :ok |
              {:error, term}

  @callback run(chan :: Hare.Chan.t, config, tags :: map) ::
              :ok |
              {:ok, info :: term} |
              {:ok, info :: term, tags :: map} |
              {:error, term}

  alias __MODULE__

  @known %{exchange:           Declarable.Exchange,
           queue:              Declarable.Queue,
           server_named_queue: Declarable.ServerNamedQueue,
           bind:               Declarable.Bind,
           unbind:             Declarable.Unbind}

  def validate(name_or_module, config, known \\ @known) do
    module = ensure_module(name_or_module, known)
    module.validate(config)
  end

  def run(chan, name_or_module, config, tags, known \\ @known) do
    module = ensure_module(name_or_module, known)
    module.run(chan, config, tags)
  end

  defp ensure_module(name_or_module, known) do
    case Map.fetch(known, name_or_module) do
      {:ok, module} -> module
      :error        -> name_or_module
    end
  end
end
