defmodule Hare.Declaration.ResultTest do
  use ExUnit.Case, async: true

  alias Hare.Declaration.Result

  test "registering events" do
    result = Result.new
             |> Result.success(:foo, [foo: "config"], :foo_info, %{})
             |> Result.success(:bar, [bar: "config"], :bar_info, %{the: "tags"})
             |> Result.failure(:baz, [baz: "config"], :baz_reason)
             |> Result.not_done(:qux, [qux: "config"])

    expected_steps = [foo: %{status: :success,
                             config: [foo: "config"],
                             info: :foo_info},
                      bar: %{status: :success,
                             config: [bar: "config"],
                             info: :bar_info},
                      baz: %{status: :failure,
                             config: [baz: "config"],
                             reason: :baz_reason},
                      qux: %{status: :not_done,
                             config: [qux: "config"]}]

    assert expected_steps == Result.steps(result)
    assert %{the: "tags"} == result.tags
  end
end
