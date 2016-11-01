defmodule Hare.Context.Action.ServerNamedQueue do
  @behaviour Hare.Context.Action

  @default_opts []

  import Hare.Context.Action.Helper.Validations,
    only: [validate: 3, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate(config, :export, :atom),
         :ok <- validate_keyword(config, :opts, required: false) do
      :ok
    end
  end

  def run(chan, config, exports) do
    export = Keyword.fetch!(config, :export)
    opts   = Keyword.get(config, :opts, @default_opts)

    with {:ok, name, info} <- do_declare(chan, opts) do
      {:ok, info, Map.put(exports, export, name)}
    end
  end

  defp do_declare(%{given: given, adapter: adapter}, opts) do
    adapter.declare_server_named_queue(given, opts)
  end
end
