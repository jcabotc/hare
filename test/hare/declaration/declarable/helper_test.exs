defmodule Hare.Declaration.HelperTest do
  use ExUnit.Case, async: true

  alias Hare.Declaration.Declarable.Helper
  require Helper

  test "validate/3" do
    config = [foo: "bar"]

    assert :ok == Helper.validate(config, :foo, :binary)

    error = {:error, {:not_atom, :foo, "bar"}}
    assert error == Helper.validate(config, :foo, :atom)

    error = {:error, {:not_present, :baz, config}}
    assert error == Helper.validate(config, :baz, :binary)

    assert :ok == Helper.validate(config, :baz, :binary, required: false)
  end

  test "validate_keyword/2" do
    config = [valid:   [foo: "bar"],
              invalid: %{foo: "bar"}]

    assert :ok == Helper.validate_keyword(config, :valid)

    error = {:error, {:not_keyword_list, :invalid, %{foo: "bar"}}}
    assert error == Helper.validate_keyword(config, :invalid)

    error = {:error, {:not_present, :baz, config}}
    assert error == Helper.validate_keyword(config, :baz)

    assert :ok == Helper.validate_keyword(config, :baz, required: false)
  end
end
