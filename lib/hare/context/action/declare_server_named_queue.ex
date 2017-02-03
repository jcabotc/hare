defmodule Hare.Context.Action.DeclareServerNamedQueue do
  @moduledoc """
  This module implements a `Hare.Context.Action` behaviour to
  declare a server-named queue on the AMQP server.

  ## Config

  Configuration must be a `Keyword.t` with the following fields:

    * `:opts` - (defaults to `[]`) the options to be given to the adapter
    * `:export_as` - (defaults to `nil`) the key to export the declared queue to

  The `:export_as` config allows the action to export a `Hare.Core.Queue`
  struct to be used later by other steps (for example: to bind it to an exchange).

  ```
  alias Hare.Context.Action.DeclareServerNamedQueue

  config = [opts: [durable: true],
            export_as: :q]

  exports = %{}

  DeclareServerNamedQueue.run(chan, config, exports)
  # => {:ok, %{...}, %{q: %Hare.Core.Queue{chan: chan, name: "as32jklqqas="}}}
  ```
  """

  @typedoc "The action configuration"
  @type config :: %{optional(:opts)      => Keyword.t,
                    optional(:export_as) => atom}

  @behaviour Hare.Context.Action

  alias Hare.Core.Queue

  @default_opts []

  import Hare.Context.Action.Helper.Validations,
    only: [validate: 4, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate(config, :export_as, :atom, required: false),
         :ok <- validate_keyword(config, :opts, required: false) do
      :ok
    end
  end

  def run(chan, config, exports) do
    opts = Keyword.get(config, :opts, @default_opts)

    with {:ok, info, queue} <- Queue.declare(chan, opts) do
      handle_exports(info, queue, exports, config)
    end
  end

  defp handle_exports(info, queue, exports, config) do
    case Keyword.fetch(config, :export_as) do
      {:ok, export_tag} ->
        {:ok, info, Map.put(exports, export_tag, queue)}
      :error ->
        {:ok, info}
    end
  end
end
