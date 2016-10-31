defmodule Hare.Core.Declaration.DeclarableTest do
  use ExUnit.Case, async: true

  alias Hare.Core.Declaration.Declarable
  alias Hare.Core.Chan

  defmodule TestDeclarable do
    @behaviour Declarable

    def validate(config),
      do: Keyword.fetch!(config, :validate)

    def run(%Chan{}, config, _tags),
      do: Keyword.fetch!(config, :run)
  end

  @known %{foo: TestDeclarable}

  test "validate/1" do
    error  = {:error, :some_reason}
    config = [validate: error]

    assert error == Declarable.validate(:foo, config, @known)
  end

  test "run/2" do
    chan = %Chan{}
    result = {:ok, :info, %{}}
    config = [run: result]

    assert result == Declarable.run(chan, TestDeclarable, config, %{})
  end
end
