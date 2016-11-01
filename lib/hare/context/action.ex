defmodule Hare.Context.Action do
  @type config :: Keyword.t

  @callback validate(config) ::
              :ok |
              {:error, term}

  @callback run(chan :: Hare.Core.Chan.t, config, exports :: map) ::
              :ok |
              {:ok, info :: term} |
              {:ok, info :: term, exports :: map} |
              {:error, term}

  alias __MODULE__

  @known %{exchange:           Action.DeclareExchange,
           declare_exchange:   Action.DeclareExchange,
           delete_exchange:    Action.DeleteExchange,
           queue:              Action.DeclareQueue,
           declare_queue:      Action.DeclareQueue,
           delete_queue:       Action.DeleteQueue,
           server_named_queue: Action.ServerNamedQueue,
           bind:               Action.Bind,
           unbind:             Action.Unbind}

  def validate(name_or_module, config, known \\ @known) do
    module = ensure_module(name_or_module, known)
    module.validate(config)
  end

  def run(chan, name_or_module, config, exports, known \\ @known) do
    module = ensure_module(name_or_module, known)
    module.run(chan, config, exports)
  end

  defp ensure_module(name_or_module, known) do
    case Map.fetch(known, name_or_module) do
      {:ok, module} -> module
      :error        -> name_or_module
    end
  end
end
