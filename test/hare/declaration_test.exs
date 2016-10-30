defmodule Hare.DeclarationTest do
  use ExUnit.Case, async: true

  alias Hare.Declaration

  defmodule TestDeclarable do
    @behaviour Declaration.Declarable

    def validate(config),
      do: Keyword.fetch!(config, :validate)

    def run(%Hare.Chan{}, config, _tags),
      do: Keyword.fetch!(config, :run)
  end

  test "validate/1" do
    steps = [{TestDeclarable, [validate: :ok]},
             {TestDeclarable, [validate: :ok]}]

    assert :ok == Declaration.validate(steps)
  end

  test "validate/1 when not keyword list" do
    steps = [TestDeclarable, :ok]
    error = {:error, :not_a_keyword_list}

    assert error == Declaration.validate(steps)
  end

  test "validate/1 on step validation error" do
    steps = [{TestDeclarable, [validate: :ok]},
             {TestDeclarable, [validate: {:error, :foo}]},
             {TestDeclarable, [validate: :ok]}]
    error = {:error, {:invalid_step, TestDeclarable, :foo}}

    assert error == Declaration.validate(steps)
  end

  @chan %Hare.Chan{}

  test "run/2" do
    config_1 = [validate: :ok, run: :ok]
    config_2 = [validate: :ok, run: {:ok, :two_info, %{foo: "bar"}}]
    config_3 = [validate: :ok, run: {:ok, :three_info}]

    steps = [{TestDeclarable, config_1},
             {TestDeclarable, config_2},
             {TestDeclarable, config_3}]

    expected_steps = [{TestDeclarable, %{status: :success,
                                         config: config_1,
                                         info:   nil}},
                      {TestDeclarable, %{status: :success,
                                         config: config_2,
                                         info:   :two_info}},
                      {TestDeclarable, %{status: :success,
                                         config: config_3,
                                         info:   :three_info}}]

    assert {:ok, result} = Declaration.run(@chan, steps)
    assert expected_steps == Declaration.Result.steps(result)
    assert %{foo: "bar"}  == result.tags
  end

  test "run/2 when invalid" do
    steps = [{TestDeclarable, [validate: :ok]},
             {TestDeclarable, [validate: {:error, :foo}]}]

    error = {:invalid, {:invalid_step, TestDeclarable, :foo}}
    assert error == Declaration.run(@chan, steps)
  end

  test "run/2 when error" do
    config_1 = [validate: :ok, run: :ok]
    config_2 = [validate: :ok, run: {:error, :foo}]
    config_3 = [validate: :ok, run: :ok]

    steps = [{TestDeclarable, config_1},
             {TestDeclarable, config_2},
             {TestDeclarable, config_3}]

    expected_steps = [{TestDeclarable, %{status: :success,
                                         config: config_1,
                                         info:   nil}},
                      {TestDeclarable, %{status: :failure,
                                         config: config_2,
                                         reason: :foo}},
                      {TestDeclarable, %{status: :not_done,
                                         config: config_3}}]

    assert {:error, result} = Declaration.run(@chan, steps)
    assert expected_steps == Declaration.Result.steps(result)
  end
end
