defmodule Hare.Declaration.Declarable.DeleteQueue do
  @behaviour Hare.Declaration.Declarable

  @default_opts []

  import Hare.Declaration.Declarable.Helper.Validations,
    only: [validate: 3, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate(config, :name, :binary),
         :ok <- validate_keyword(config, :opts, required: false) do
      :ok
    end
  end

  def run(%{given: given, adapter: adapter}, config, _tags) do
    name = Keyword.fetch!(config, :name)
    opts = Keyword.get(config, :opts, @default_opts)

    adapter.delete_queue(given, name, opts)
  end
end
