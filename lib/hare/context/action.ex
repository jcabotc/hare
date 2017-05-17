defmodule Hare.Context.Action do
  @moduledoc """
  This module defines the behaviour all actions must implement to be
  run as a step in a context.

  ## Default actions

  The following common actions are implemented by default and can be referenced
  with an atom instead of the whole module name:

    * `declare_exchange` - (`Action.DeclareExchange`) declares an exchange
    * `exchange` - (`Action.DeclareExchange`) alias for `:declare_exchange`
    * `default_exchange` - (`Action.DefaultExchange`) noop to produce the default exchange
    * `delete_exchange` - (`Action.DeleteExchange`) deletes an exchange
    * `declare_queue` - (`Action.DeclareQueue`) declares a queue
    * `queue` - (`Action.DeclareQueue`) alias for `:declare_queue`
    * `delete_queue` - (`Action.DeleteQueue`) deletes a queue
    * `declare_server_named_queue -  (`Action.DeclareServerNamedQueue`) declares a server-named queue
    * `server_named_queue` - (`Action.DeclareServerNamedQueue`) alias for `:declare_server_named_queue`
    * `bind` - (`Action.Bind`) binds a queue to an exchange
    * `unbind` - (`Action.Unbind`) unbinds a queue from an exchange

  Check each action module for more information about its configuration format.
  """

  @type t :: module | atom

  @typedoc "The configuration of an action"
  @type config :: Keyword.t

  @doc """
  Validates the given config format.

  It must return `:ok` if config is valid, and `{:error, reason}` if
  it is invalid.
  """
  @callback validate(config) ::
              :ok |
              {:error, reason :: term}

  @typedoc "Information about the execution of an action"
  @type info :: term

  @typedoc "A map containing the data exported from previously executed steps"
  @type exports :: map

  @doc """
  Runs the action.

  It receives a open AMQP channel, the config of the action, and the
  exports map, containing data from previous run actions.

  It may return 4 possible values:

    * `:ok` - On success (info is %{} by default)
    * `{:ok, info}` - On success, providing some info about the execution of the step
    * `{:ok, info, exports}` - On success, providing some info, with a modified exports map
    * `{:error, reason}` - On error
  """
  @callback run(chan :: Hare.Core.Chan.t, config, exports) ::
              :ok |
              {:ok, info} |
              {:ok, info, exports} |
              {:error, reason :: term}

  alias __MODULE__

  @known %{exchange:                   Action.DeclareExchange,
           declare_exchange:           Action.DeclareExchange,
           default_exchange:           Action.DefaultExchange,
           delete_exchange:            Action.DeleteExchange,
           queue:                      Action.DeclareQueue,
           declare_queue:              Action.DeclareQueue,
           delete_queue:               Action.DeleteQueue,
           declare_server_named_queue: Action.DeclareServerNamedQueue,
           server_named_queue:         Action.DeclareServerNamedQueue,
           bind:                       Action.Bind,
           unbind:                     Action.Unbind,
           qos:                        Action.Qos}

  @doc false
  def validate(name_or_module, config, known \\ @known) do
    module = ensure_module(name_or_module, known)
    module.validate(config)
  end

  @doc false
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
