defmodule Hare.RPC.Server.StepsTest do
  use ExUnit.Case, async: true

  alias Hare.RPC.Server.Steps

  defmodule ValidContext do
    def validate(_steps),
      do: :ok

    def run(chan, steps, opts),
      do: {:ok, %{exports: %{args: {chan, steps, opts}}}}
  end
  defmodule InvalidContext do
    def validate(_steps),
      do: {:error, :invalid}
  end

  test "parse/2 with valid context" do
    config = [queue: [name: "foo",
                      opts: [durable: true]]]

    expected = [default_exchange: [
                  export_as: :exchange],
                declare_queue: [
                  export_as: :queue,
                  name:      "foo",
                  opts:      [durable: true]]]

    assert {:ok, expected} == Steps.parse(config, ValidContext)
  end

  test "parse/2 on :queue config error" do
    config = []
    assert {:error, {:not_present, :queue}} == Steps.parse(config, ValidContext)

    config = [queue: "foo"]
    assert {:error, {:not_keyword_list, :queue}} == Steps.parse(config, ValidContext)
  end

  test "parse/2 with invalid context" do
    config = [queue: [name: "foo",
                      opts: [durable: true]]]

    assert {:error, :invalid} == Steps.parse(config, InvalidContext)
  end

  test "run/3" do
    chan  = :fake_chan
    steps = :fake_steps

    expected_args = {chan, steps, validate: false}
    assert {:ok, %{args: expected_args}} == Steps.run(chan, steps, ValidContext)
  end
end
