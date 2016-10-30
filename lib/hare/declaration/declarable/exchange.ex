defmodule Hare.Declaration.Declarable.Exchange do
  @behaviour Hare.Declaration.Declarable

  @default_type :direct
  @default_opts []

  import Hare.Declaration.Declarable.Helper,
    only: [validate: 3, validate: 4, validate_keyword: 3]

  def validate(config) do
    with :ok <- validate(config, :name, :binary),
         :ok <- validate(config, :type, :atom, required: false),
         :ok <- validate_keyword(config, :opts, required: false) do
      :ok
    end
  end

  def run(%{given: given, adapter: adapter}, config, _tags) do
    name = Keyword.fetch!(config, :name)
    type = Keyword.get(config, :type, @default_type)
    opts = Keyword.get(config, :opts, @default_opts)

    adapter.declare_exchange(given, name, type, opts)
  end
end
