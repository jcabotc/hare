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
       {:hare, "~> 0.1.9"}]
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

The `Hare.Conn` starts a process that wraps a real connection. Starts a connection,
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

A module implementing a `Hare.Publisher` must implement some callbacks (a default
implementation is provided with `use Hare.Publisher`)

```elixir
defmodule MyPublisher do
  use Hare.Publisher

  @config Application.get_env(:my_app, :my_publisher)

  def start_link(conn, blacklist) do
    Hare.Publisher.start_link(__MODULE__, conn, @config, blacklist)
  end

  defdelegate publish(pid, payload), to: Hare.Publisher

  #
  # Callbacks
  #
  def init(blacklist) do
    {:ok, %{blacklist: blacklist}}
  end

  def before_publication(payload, _routing_key, _opts, state) do
    case Enum.member?(state.blacklist, payload) do
      true  -> {:ok, state}
      false -> {:ignore, state}
    end
  end
end
```

The above snippet implements a publisher. It receives a payloads blacklist
when starts and keeps it in its internal state.

Before sending a message to the exchange it runs the `before_publication/4` callback
that allows the publisher to ignore that message if it is blacklisted instead of
publishing it.

For more information about all available callbacks and its possible return values
check `Hare.Publisher` documentation.

## Consumer

Another provided is the `Hare.Consumer`. It allows to consume messages from
a particular queue.

It expects a connection and the exchange, queue, and binding configuration
in the following format:

```elixir
config = [exchange: [name: "the.exchange.name",
                     type: :direct,
                     opts: [durable: true]],
          queue: [name: "the.queue.name",
                  opts: [durable: true]],
          bind: [routing_key: "the.routing.key"]]
```

A module implementing a `Hare.Consumer` must implement some callbacks (a default
implementation is provided with `use Hare.Consumer`)

```elixir
defmodule MyConsumer do
  use Hare.Consumer

  @config Application.get_env(:my_app, :my_consumer)

  def start_link(conn, handler) do
    Hare.Consumer.start_link(__MODULE__, conn, @config, handler)
  end

  #
  # Callbacks
  #
  def init(handler) do
    {:ok, %{handler: handler}}
  end

  def handle_message(payload, meta, %{handler: handler} = state) do
    on_success = fn -> Hare.Consumer.ack(meta) end
    on_failure = fn -> Hare.Consumer.reject(meta) end

    handler.(payload, on_success, on_failure)

    {:noreply, state}
  end
end
```

The above snippet implements a consumer. It receives a handler function
when starts and keeps it in its internal state.

When a message is received from the queue, the `handle_message/3` callback
is called with the payload of the message, some metadata, and the internal
state of the consumer.

On the example above the `handle_message/3` callback builds 2 anonymous functions,
one for a successfull scenario and another for an unexpected failure scenario,
and calls the handler with the payload and both functions.

This handler call may start another process, that will be able to ack or reject the
message depending on the success of the message handling.

For more information about all available callbacks and its possible return values
check `Hare.Consumer` documentation.

## RPC client

The abstraction `Hare.RPC.Client` represents the client of a RPC communication
through the AMQP server. It allows to publish messages and wait for its responses.

It expects a connection and the exchange configuration in the following format:

```elixir
config = [exchange: [name: "the.exchange.name",
                     type: :direct,
                     opts: [durable: true]]]
```

A module implementing a `Hare.RPC.Client` must implement some callbacks (a default
implementation is provided with `use Hare.RPC.Client`)

```elixir
defmodule MyClient do
  use Hare.RPC.Client

  @config Application.get_env(:my_app, :my_client)

  def start_link(conn) do
    Hare.RPC.Client.start_link(__MODULE__, conn, @config, :ok)
  end

  #
  # Callbacks
  #
  def init(:ok) do
    {:ok, %{pending: %{}, cache: %{}}}
  end

  def before_request(payload, _routing_key, _opts, from, state) do
    case Map.fetch(state.cache, payload) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}

      :error ->
        new_pending = Map.put(state.pending, from, payload)
        {:ok, %{state | pending: new_pending}}
    end
  end

  def on_response(response, from, state) do
    {payload, new_pending} = Map.pop(state.pending, from)
    new_cache = Map.put(state.cache, payload, response)

    {:reply, {:ok, response}, %{state | pending: new_pending, cache: new_cache}}
  end
end
```

The above snippet implements a cached RPC client. It keeps pending requests data and
a cache in its internal state.

Before performing the request it checks if the current payload is already cached, if so
it replies to the caller without performing the request.

If the current payload is not cached it stores it in relation with a term representing
the caller as a pending request.

When the response arrives it gets the payload of that call from the pending requests,
stores the payload-response relation in cache, and responds to the caller.

For more information about all available callbacks and its possible return values
check `Hare.RPC.Client` documentation.

## RPC Server

The other side of the RPC Client is represented by the `Hare.RPC.Server` abstraction.
It allows to consume requests from a particular queue and reply to the
specified queue through the default exchange.

It expects a connection and the exchange, queue, and binding configuration
in the following format:

```elixir
config = [exchange: [name: "the.exchange.name",
                     type: :direct,
                     opts: [durable: true]],
          queue: [name: "the.queue.name",
                  opts: [durable: true]],
          bind: [routing_key: "the.routing.key"]]
```

A module implementing a `Hare.RPC.Server` must implement some callbacks (a default
implementation is provided with `use Hare.RPC.Server`)

```elixir
defmodule MyServer do
  use Hare.RPC.Server

  @config Application.get_env(:my_app, :my_server)

  def start_link(conn, handler) do
    Hare.RPC.Server.start_link(__MODULE__, conn, @config, handler)
  end

  #
  # Callbacks
  #
  def init(handler) do
    {:ok, %{handler: handler}}
  end

  def handle_message(payload, meta, %{handler: handler} = state) do
    callback = &Hare.RPC.Server.reply(meta, &1)

    handler.(payload, callback)
    {:noreply, state}
  end
end
```

The above snippet implements a rpc server. It receives a handler function
when starts and keeps it in its internal state.

When a message is received from the queue, the `handle_message/3` callback
is called with the payload of the message, some metadata, and the internal
state of the rpc server.

On the example above the `handle_message/3` builds a callback to be used
to send a response to the client, and calls the handler with the payload
and the callback.

This handler call may start another process, that will be able to respond to
the client when the response is built.

For more information about all available callbacks and its possible return values
check `Hare.RPC.Server` documentation.
