defmodule Hare.Actor.RPC.Server.DeclarationTest do
  use ExUnit.Case, async: true

  alias Hare.Actor.RPC.Server.Declaration

  defmodule ValidContext do
    def validate(_steps),
      do: :ok

    def run(chan, _steps, _opts) do
      exports = %{request_exchange:  {:fake_request_exchange, chan},
                  request_queue:     {:fake_request_queue, chan},
                  response_exchange: {:fake_response_exchange, chan}}

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
                         opts: [durable: true]],
              queue: [name: "bar",
                      opts: [durable: true]],
              bind: [routing_key: "baz.*"]]

    assert {:ok, declaration} = Declaration.parse(config, ValidContext)

    assert declaration.context == ValidContext
    assert declaration.steps == [default_exchange: [
                                   export_as: :response_exchange],
                                 declare_exchange: [
                                   export_as: :request_exchange,
                                   name:      "foo",
                                   type:      :fanout,
                                   opts:      [durable: true]],
                                 declare_queue: [
                                   export_as: :request_queue,
                                   name:      "bar",
                                   opts:      [durable: true]],
                                 bind: [
                                   opts:                 [routing_key: "baz.*"],
                                   exchange_from_export: :request_exchange,
                                   queue_from_export:    :request_queue]]

    chan = :fake_chan
    assert {:ok, request_queue, response_exchange} = Declaration.run(declaration, chan)
    assert {:fake_request_queue, ^chan}     = request_queue
    assert {:fake_response_exchange, ^chan} = response_exchange
  end

  test "parse/2 on :exchange config error" do
    config = [queue: [name: "bar", opts: []]]
    assert {:error, {:not_present, :exchange}} == Declaration.parse(config, ValidContext)

    config = [exchange: "foo", queue: [name: "bar", opts: []]]
    assert {:error, {:not_keyword_list, :exchange}} == Declaration.parse(config, ValidContext)
  end

  test "parse/2 on :queue config error" do
    config = [exchange: [name: "foo", type: :fanout, opts: []]]
    assert {:error, {:not_present, :queue}} == Declaration.parse(config, ValidContext)

    config = [exchange: [name: "foo", type: :fanout, opts: []], queue: "bar"]
    assert {:error, {:not_keyword_list, :queue}} == Declaration.parse(config, ValidContext)
  end

  test "parse/2 with invalid context" do
    config = [exchange: [name: "foo",
                         type: :fanout,
                         opts: [durable: true]],
              queue: [name: "bar",
                      opts: [durable: true]]]

    assert {:error, :invalid} == Declaration.parse(config, InvalidContext)
  end
end
