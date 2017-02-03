defmodule Hare.Context.Action.DeleteQueue do
  @moduledoc """
  This module implements a `Hare.Context.Action` behaviour to
  delete an queue from the AMQP server.

  ## Config

  Configuration must be a `Keyword.t` with the following fields:

    * `:name` - the name of the queue
    * `:opts` - (defaults to `[]`) the options to be given to the adapter
    * `:export_as` - (defaults to `nil`) the key to export the deleted queue to

  The `:export_as` config allows the action to export a `Hare.Core.Queue`
  struct to be used later by other steps (for example: to redeclare it with another opts).

  ```
  alias Hare.Context.Action.DeleteQueue

  config = [name: "foo",
            opts: [no_wait: true],
            export_as: :deleted_ex]

  exports = %{}

  DeleteQueue.run(chan, config, exports)
  # => {:ok, nil, %{deleted_ex: %Hare.Core.Queue{chan: chan, name: "foo"}}}
  ```
  """

  @typedoc "The action configuration"
  @type config :: %{required(:name) => binary,
                    optional(:opts) => Keyword.t,
                    optional(:export_as) => atom}

  @behaviour Hare.Context.Action

  alias Hare.Core.Queue

  @default_opts []

  alias Hare.Core.Queue
  alias Hare.Context.Action.Helper
  import Helper.Validations, only: [validate: 4, validate_keyword: 3]
  import Helper.Exports,     only: [validate_name_or_export: 3, get_name_or_export: 4]

  def validate(config) do
    with :ok <- validate_name_or_export(config, :name, :queue_from_export),
         :ok <- validate_keyword(config, :opts, required: false),
         :ok <- validate(config, :export_as, :atom, required: false) do
      :ok
    end
  end

  def run(chan, config, exports) do
    with {:ok, queue} <- get_queue(chan, config, exports) do
      opts = Keyword.get(config, :opts, @default_opts)

      with {:ok, info} <- Queue.delete(queue, opts) do
        handle_exports(queue, info, exports, config)
      end
    end
  end

  defp get_queue(chan, config, exports) do
    case get_name_or_export(config, exports, :name, :queue_from_export) do
      {:name, name}    -> {:ok, Queue.new(chan, name)}
      {:export, queue} -> {:ok, queue}
    end
  end

  defp handle_exports(queue, info, exports, config) do
    case Keyword.fetch(config, :export_as) do
      {:ok, export_tag} ->
        {:ok, info, Map.put(exports, export_tag, queue)}
      :error ->
        {:ok, info}
    end
  end
end
