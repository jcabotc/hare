defmodule Hare.RPC.Client.DeclarationTest do
  use ExUnit.Case, async: true

  alias Hare.RPC.Client.Declaration

  defmodule ValidContext do
    def validate(_steps),
      do: :ok

    def run(chan, _steps, _opts) do
      exports = %{request_queue:  {:fake_request_queue, chan},
                  response_queue: {:fake_response_queue, chan},
                  exchange:       {:fake_exchange, chan}}

      {:ok, %{exports: exports}}
    end
  end
  defmodule InvalidContext do
    def validate(_steps),
      do: {:error, :invalid}
  end

  test "parse/2 with valid context" do
    config = [queue: [name: "foo",
                      opts: [durable: true]]]

    assert {:ok, declaration} = Declaration.parse(config, ValidContext)

    assert declaration.context == ValidContext
    assert declaration.steps == [default_exchange: [
                                   export_as: :exchange],
                                 declare_server_named_queue: [
                                   export_as: :response_queue,
                                   opts:      [auto_delete: true, exclusive: true]],
                                 declare_queue: [
                                   export_as: :request_queue,
                                   name:      "foo",
                                   opts:      [durable: true]]]

    chan   = :fake_chan
    result = Declaration.run(declaration, chan)

    assert {:ok, request_queue, response_queue, exchange} = result
    assert {:fake_request_queue, ^chan} = request_queue
    assert {:fake_response_queue, ^chan} = response_queue
    assert {:fake_exchange, ^chan} = exchange
  end

  test "parse/2 on :queue config error" do
    config = []
    assert {:error, {:not_present, :queue}} == Declaration.parse(config, ValidContext)

    config = [queue: "foo"]
    assert {:error, {:not_keyword_list, :queue}} == Declaration.parse(config, ValidContext)
  end

  test "parse/2 with invalid context" do
    config = [queue: [name: "foo",
                      opts: [durable: true]]]

    assert {:error, :invalid} == Declaration.parse(config, InvalidContext)
  end
end
