# Hare

Tools and abstractions to interact with AMQP servers.

## Hello world

Define a publisher:

```elixir
defmodule MyPublisher do
  use Hare.Publisher

  @config [exchange: [name: "foo"]]

  def start_link(conn) do
    Hare.Publisher.start_link(__MODULE__, conn, @config, [])
  end

  def publish(publisher, payload) do
    Hare.Publisher.publish(publisher, payload)
  end
end
```

Define a consumer:

```elixir
defmodule MyConsumer do
  use Hare.Consumer

  @config [exchange: [name: "foo"],
           queue:    [name: "bar"]]

  def start_link(conn, config) do
    Hare.Consumer.start_link(__MODULE__, conn, config, [])
  end

  def handle_message(payload, _meta, state) do
    IO.puts(payload)

    {:reply, :ack, state}
  end
end
```

Publish and consume a message:

```elixir
{:ok, conn} = Hare.Conn.start_link(adapter: Hare.Adapter.AMQP)

{:ok, publisher} = MyPublisher.start_link(conn)
{:ok, _consumer} = MyConsumer.start_link(conn)

MyPublisher.publish(publisher, "hello world!")
# => Prints "hello world!\n"
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `hare` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:amqp, "~> 0.1.4", hex: :amqp19},
       {:hare, "~> 0.1.7"}]
    end
    ```

  2. Ensure `hare` is started before your application:

    ```elixir
    def application do
      [applications: [:hare]]
    end
    ```

## The Hare.Conn

The first step to interact with an AMQP server is to establish a connection.

The `Hare.Conn` starts a process that wraps a real connection. Starts a connection ,
monitors it, and reconnects on failure.

```elixir
{:ok, conn} = Hare.Conn.start_link(adapter: Hare.Adapter.AMQP,
                                   backoff: [0, 100, 1000],
                                   config:  [host: "localhost", port: 1234])
# => {:ok, %Hare.Core.Conn{...}}
```

The example above shows all available options when starting a connection.

The `:adapter` option is mandatory and it specifies what adapter to use.
An adapter must implement the `Hare.Adapter` behaviour which includes functions
like connecting to the server, opening channels, declaring queues, publishing
messages, etc.

The only adapter provided is `Hare.Adapter.AMQP` that uses the `AMQP` library.
Note that in order to use the `Hare.Adapter.AMQP`, the `:amqp` must be explicitly
included as a dependency.

The `:backoff` option specifies a set of intervals to wait before retrying connection
in case of failure. It defaults to `[0, 10, 100, 1000, 5000]`.

On successive connection failures it waits successive intervals before retrying
and then keeps waiting for the last interval to retry forever.

The `:config` option will be given without modification to the adapter
`open_connection/1` function. It defaults to `[]`.

## Publisher

The simplest abstraction provided is the `Hare.Publisher`. It allows to publish
messages to a particular exchange.

It expects a connection and the exchange configuration in the following format:

```elixir
config = [exchange: [name: "the.exchange.name",
                     type: :direct,
                     opts: [durable: true]]]
```

The only mandatory option is `:name` specifying the name of the exchange to publish
to. `:type` defaults to `:direct`, and `:opts` defaults to `[]`.
