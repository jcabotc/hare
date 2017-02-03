defmodule Hare.Context.Action.DeclareQueue do
  @moduledoc """
  This module implements a `Hare.Context.Action` behaviour to
  declare a queue on the AMQP server.

  ## Config

  Configuration must be a `Keyword.t` with the following fields:

    * `:name` - the name of the queue
    * `:opts` - (defaults to `[]`) the options to be given to the adapter
    * `:export_as` - (defaults to `nil`) the key to export the declared queue to

  The `:export_as` config allows the action to export a `Hare.Core.Queue`
  struct to be used later by other steps (for example: to bind it to an exchange)

  ```
  alias Hare.Context.Action.DeclareQueue

  config = [name: "foo",
            opts: [durable: true],
            export_as: :my_queue]

  exports = %{}

  DeclareQueue.run(chan, config, exports)
  # => {:ok, %{...}, %{my_queue: %Hare.Core.Queue{chan: chan, name: "foo"}}}
  ```
  """

  @typedoc "The action configuration"
  @type config :: %{required(:name)      => binary,
                    optional(:opts)      => Keyword.t,
                    optional(:export_as) => atom}

  @behaviour Hare.Context.Action

  alias Hare.Core.Queue

  @default_opts []

  import Hare.Context.Action.Helper.Validations,
    only: [validate: 3, validate: 4, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate(config, :name, :binary),
         :ok <- validate_keyword(config, :opts, required: false),
         :ok <- validate(config, :export_as, :atom, required: false) do
      :ok
    end
  end

  def run(chan, config, exports) do
    name = Keyword.fetch!(config, :name)
    opts = Keyword.get(config, :opts, @default_opts)

    with {:ok, info, queue} <- Queue.declare(chan, name, opts) do
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
