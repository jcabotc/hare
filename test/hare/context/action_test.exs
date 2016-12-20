defmodule Hare.Context.ActionTest do
  use ExUnit.Case, async: true

  alias Hare.Context.Action
  alias Hare.Core.Chan

  defmodule TestAction do
    @behaviour Action

    def validate(config),
      do: Keyword.fetch!(config, :validate)

    def run(%Chan{}, config, _exports),
      do: Keyword.fetch!(config, :run)
  end

  @known %{foo: TestAction}

  test "validate/1" do
    error  = {:error, :some_reason}
    config = [validate: error]

    assert error == Action.validate(:foo, config, @known)
  end

  test "run/2" do
    chan = %Chan{}
    result = {:ok, :info, %{}}
    config = [run: result]

    assert result == Action.run(chan, TestAction, config, %{})
  end
end
