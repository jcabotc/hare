defmodule Hare.Declaration.Declarable.ServerNamedQueue do
  @behaviour Hare.Declaration.Declarable

  @default_opts []

  import Hare.Declaration.Declarable.Helper.Validations,
    only: [validate: 3, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate(config, :tag, :atom),
         :ok <- validate_keyword(config, :opts, required: false) do
      :ok
    end
  end

  def run(chan, config, tags) do
    tag  = Keyword.fetch!(config, :tag)
    opts = Keyword.get(config, :opts, @default_opts)

    with {:ok, name, info} <- do_declare(chan, opts) do
      {:ok, info, Map.put(tags, tag, name)}
    end
  end

  defp do_declare(%{given: given, adapter: adapter}, opts) do
    adapter.declare_server_named_queue(given, opts)
  end
end
