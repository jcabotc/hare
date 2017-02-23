defmodule Hare.RPC.Client.DeclarationTest do
  use ExUnit.Case, async: true

  alias Hare.RPC.Client.Declaration

  defmodule ValidContext do
    def validate(_steps),
      do: :ok

    def run(chan, _steps, _opts) do
      exports = %{response_queue:   {:fake_response_queue, chan},
                  request_exchange: {:fake_request_exchange, chan}}

      {:ok, %{exports: exports}}
    end
  end
  defmodule InvalidContext do
    def validate(_steps),
      do: {:error, :invalid}
  end

  test "parse/2 with valid context" do
    config = [exchange: [name: "foo",
                         type: :fanout,
                         opts: [durable: true]]]

    assert {:ok, declaration} = Declaration.parse(config, ValidContext)

    assert declaration.context == ValidContext
    assert declaration.steps == [declare_server_named_queue: [
                                   export_as: :response_queue,
                                   opts:      [auto_delete: true, exclusive: true]],
                                 declare_exchange: [
                                   export_as: :request_exchange,
                                   name: "foo",
                                   type: :fanout,
                                   opts: [durable: true]]]

    chan   = :fake_chan
    result = Declaration.run(declaration, chan)

    assert {:ok, response_queue, request_exchange} = result
    assert {:fake_request_exchange, ^chan} = request_exchange
    assert {:fake_response_queue, ^chan}   = response_queue
  end

  test "parse/2 on :exchange empty config" do
    config = []

    assert {:ok, declaration} = Declaration.parse(config, ValidContext)

    assert declaration.context == ValidContext
    assert declaration.steps == [declare_server_named_queue: [
                                   export_as: :response_queue,
                                   opts:      [auto_delete: true, exclusive: true]],
                                 default_exchange: [
                                   export_as: :request_exchange]]

    chan   = :fake_chan
    result = Declaration.run(declaration, chan)

    assert {:ok, response_queue, request_exchange} = result
    assert {:fake_request_exchange, ^chan} = request_exchange
    assert {:fake_response_queue, ^chan}   = response_queue
  end

  test "parse/2 on :exchange config error" do
    config = [exchange: "foo"]
    assert {:error, {:not_keyword_list, :exchange}} == Declaration.parse(config, ValidContext)
  end

  test "parse/2 with invalid context" do
    config = [exchange: [name: "foo",
                         type: :fanout,
                         opts: [durable: true]]]

    assert {:error, :invalid} == Declaration.parse(config, InvalidContext)
  end
end
