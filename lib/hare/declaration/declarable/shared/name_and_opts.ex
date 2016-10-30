defmodule Hare.Declaration.Declarable.Shared.NameAndOpts do
  @default_opts []

  import Hare.Declaration.Declarable.Helper.Validations,
    only: [validate: 3, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate(config, :name, :binary),
         :ok <- validate_keyword(config, :opts, required: false) do
      :ok
    end
  end

  def run(%{given: given, adapter: adapter}, action, config) do
    name = Keyword.fetch!(config, :name)
    opts = Keyword.get(config, :opts, @default_opts)

    apply(adapter, action, [given, name, opts])
  end
end
