defmodule Hare.Declaration.DeclarableTest do
  use ExUnit.Case, async: true

  alias Hare.Declaration.Declarable

  defmodule TestDeclarable do
    @behaviour Declarable

    def validate(config),
      do: Keyword.fetch!(config, :validate)

    def run(%Hare.Chan{}, config, _tags),
      do: Keyword.fetch!(config, :run)
  end

  @known %{foo: TestDeclarable}

  test "validate/1" do
    error  = {:error, :some_reason}
    config = [validate: error]

    assert error == Declarable.validate(:foo, config, @known)
  end

  test "run/2" do
    chan = %Hare.Chan{}
    result = {:ok, :info, %{}}
    config = [run: result]

    assert result == Declarable.run(chan, TestDeclarable, config, %{})
  end
end
