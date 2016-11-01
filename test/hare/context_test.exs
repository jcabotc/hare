defmodule Hare.ContextTest do
  use ExUnit.Case, async: true

  alias Hare.Context
  alias Hare.Core.Chan

  defmodule TestAction do
    @behaviour Context.Action

    def validate(config),
      do: Keyword.fetch!(config, :validate)

    def run(%Chan{}, config, _tags),
      do: Keyword.fetch!(config, :run)
  end

  test "validate/1" do
    steps = [{TestAction, [validate: :ok]},
             {TestAction, [validate: :ok]}]

    assert :ok == Context.validate(steps)
  end

  test "validate/1 when not keyword list" do
    steps = [TestAction, :ok]
    error = {:error, :not_a_keyword_list}

    assert error == Context.validate(steps)
  end

  test "validate/1 on step validation error" do
    steps = [{TestAction, [validate: :ok]},
             {TestAction, [validate: {:error, :foo}]},
             {TestAction, [validate: :ok]}]
    error = {:error, {:invalid_step, TestAction, :foo}}

    assert error == Context.validate(steps)
  end

  @chan %Chan{}

  test "run/2" do
    config_1 = [validate: :ok, run: :ok]
    config_2 = [validate: :ok, run: {:ok, :two_info, %{foo: "bar"}}]
    config_3 = [validate: :ok, run: {:ok, :three_info}]

    steps = [{TestAction, config_1},
             {TestAction, config_2},
             {TestAction, config_3}]

    expected_steps = [{TestAction, %{status: :success,
                                     config: config_1,
                                     info:   nil}},
                      {TestAction, %{status: :success,
                                     config: config_2,
                                     info:   :two_info}},
                      {TestAction, %{status: :success,
                                     config: config_3,
                                     info:   :three_info}}]

    assert {:ok, result} = Context.run(@chan, steps)
    assert expected_steps == Context.Result.steps(result)
    assert %{foo: "bar"}  == result.tags
  end

  test "run/2 when invalid" do
    steps = [{TestAction, [validate: :ok]},
             {TestAction, [validate: {:error, :foo}]}]

    error = {:invalid, {:invalid_step, TestAction, :foo}}
    assert error == Context.run(@chan, steps)
  end

  test "run/2 when error" do
    config_1 = [validate: :ok, run: :ok]
    config_2 = [validate: :ok, run: {:error, :foo}]
    config_3 = [validate: :ok, run: :ok]

    steps = [{TestAction, config_1},
             {TestAction, config_2},
             {TestAction, config_3}]

    expected_steps = [{TestAction, %{status: :success,
                                     config: config_1,
                                     info:   nil}},
                      {TestAction, %{status: :failure,
                                     config: config_2,
                                     reason: :foo}},
                      {TestAction, %{status: :not_done,
                                     config: config_3}}]

    assert {:error, result} = Context.run(@chan, steps)
    assert expected_steps == Context.Result.steps(result)
  end
end
