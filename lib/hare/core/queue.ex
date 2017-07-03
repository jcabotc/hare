defmodule Hare.Core.Queue do
  @moduledoc """
  This module defines the `Hare.Core.Queue` struct that represents
  an queue and holds a channel to interact with it.
  """

  alias __MODULE__
  alias Hare.Core.{Chan, Exchange}

  @type chan          :: Chan.t
  @type name          :: Hare.Adapter.queue_name
  @type consuming     :: boolean
  @type consuming_pid :: pid
  @type consumer_tag  :: Hare.Adapter.consumer_tag

  @type t :: %__MODULE__{
              chan:          chan,
              name:          name,
              consuming:     consuming,
              consuming_pid: consuming_pid | nil,
              consumer_tag:  consumer_tag | nil}

  defstruct chan:          nil,
            name:          nil,
            consuming:     false,
            consuming_pid: nil,
            consumer_tag:  nil

  @type payload :: Hare.Adapter.payload
  @type meta    :: Hare.Adapter.meta
  @type opts    :: Hare.Adapter.opts

  @doc """
  Builds a queue with the given name associated to the given channel.

  The queue is supposed to already be declared on the server in order
  to use it to run functions like `publish/4`.

  Is recommended to always use `declare/3` instead of `new/2` in order to
  ensure the queue is already declared as expected before using it.
  """
  @spec new(chan, name) :: t
  def new(%Chan{} = chan, name) when is_binary(name),
    do: %Queue{chan: chan, name: name}

  @doc """
  Declares a server-named queue on the AMQP server through the given channel, and
  builds a queue struct associated to that channel.
  """
  @spec declare(chan) :: {:ok, info :: term, t} |
                         {:error, reason :: term}
  def declare(chan),
    do: declare(chan, [])

  @doc """
  Declares a queue on the AMQP server through the given channel, and
  builds a queue struct associated to that channel.

  When the second argument is a binary, it is interpreted as the name of the
  queue. A queue with that name and no options is declared.

  Otherwise, the second argument is interpreted as the options to declare the
  exchange. A server-named queue with that options is declared.

  ```
  # Declares a queue named: foo
  {:ok, _info, queue} = Queue.declare(chan, "foo")
  # => %Queue{name: "foo", chan: chan}

  # Declares an exclusive, server-named queue
  {:ok, _info, queue} = Queue.declare(chan, exclusive: true)
  # => %Queue{name: "nas=eq3as.ndf?ea", chan: chan}
  ```
  """
  @spec declare(chan, name | opts) :: {:ok, info :: term, t} |
                                      {:error, reason :: term}
  def declare(chan, name) when is_binary(name),
    do: declare(chan, name, [])
  def declare(%Chan{} = chan, opts) do
    %{given: given, adapter: adapter} = chan

    with {:ok, name, info} <- adapter.declare_server_named_queue(given, opts) do
      {:ok, info, %Queue{chan: chan, name: name}}
    end
  end

  @doc """
  Declares a queue with the given name and options through the given
  channel, and builds a queue struct associated to that channel.
  """
  @spec declare(chan, name, opts) :: {:ok,  info :: term, t} |
                                     {:error, reason :: term}
  def declare(%Chan{} = chan, name, opts)
  when is_binary(name) do
    %{given: given, adapter: adapter} = chan

    with {:ok, info} <- adapter.declare_queue(given, name, opts) do
      {:ok, info, %Queue{chan: chan, name: name}}
    end
  end

  @doc """
  Binds the queue to a existing exchange.

  The second argument can be an exchange (`Hare.Core.Exchange` struct) or a binary
  representing the name of the exchange to bind to.

  The exchange is supposed to be already declared, therefore it is recommended to declare
  the exchange with `Exchange.declare/4` and use the resulting exchange as
  `bind/3` second argument.
  """
  @spec bind(t, Exchange.t | binary, opts) :: :ok
  def bind(queue, exchange_or_name, opts \\ [])
  def bind(%Queue{chan: chan} = queue, exchange_name, opts)
  when is_binary(exchange_name) do
    exchange = Exchange.new(chan, exchange_name)

    bind(queue, exchange, opts)
  end
  def bind(%Queue{chan: chan, name: name} = queue,
           %Exchange{name: exchange_name} = exchange, opts) do
    %{given: given, adapter: adapter} = chan

    with :ok <- adapter.bind(given, name, exchange_name, opts) do
      {:ok, queue, exchange}
    end
  end

  @doc """
  Unbinds the queue from a existing exchange.

  The second argument can be an exchange (`Hare.Core.Exchange` struct) or a binary
  representing the name of the exchange to bind to.

  The exchange is supposed to be already declared, therefore it is recommended to declare
  the exchange with `Exchange.declare/4` and use the resulting exchange as
  `unbind/3` second argument.
  """
  @spec unbind(t, Exchange.t | binary, opts) :: :ok
  def unbind(queue, exchange_or_name, opts \\ [])
  def unbind(%Queue{chan: chan} = queue, exchange_name, opts)
  when is_binary(exchange_name) do
    exchange = Exchange.new(chan, exchange_name)

    unbind(queue, exchange, opts)
  end
  def unbind(%Queue{chan: chan, name: name} = queue,
             %Exchange{name: exchange_name} = exchange, opts) do
    %{given: given, adapter: adapter} = chan

    with :ok <- adapter.unbind(given, name, exchange_name, opts) do
      {:ok, queue, exchange}
    end
  end

  @doc """
  Gets a message from the queue through the associated channel.
  """
  @spec get(t, opts) :: {:empty, info :: term} |
                        {:ok, payload, meta}
  def get(%Queue{chan: chan, name: name}, opts \\ []) do
    %{given: given, adapter: adapter} = chan

    adapter.get(given, name, opts)
  end

  @doc "Acks a message given its meta."
  @spec ack(t, meta, opts) :: :ok
  def ack(%Queue{chan: %{given: given, adapter: adapter}}, meta, opts \\ []),
    do: adapter.ack(given, meta, opts)

  @doc "Nacks a message given its meta."
  @spec nack(t, meta, opts) :: :ok
  def nack(%Queue{chan: %{given: given, adapter: adapter}}, meta, opts \\ []),
    do: adapter.nack(given, meta, opts)

  @doc "Rejects a message given its meta."
  @spec reject(t, meta, opts) :: :ok
  def reject(%Queue{chan: %{given: given, adapter: adapter}}, meta, opts \\ []),
    do: adapter.reject(given, meta, opts)

  @doc """
  Delegates to `consume/3` with caller's pid and empty options.
  """
  @spec consume(t) :: {:ok, t} |
                      {:error, :already_consuming}
  def consume(queue), do: consume(queue, self(), [])

  @doc """
  When the second argument is a pid it delegates to `consume/3` with that
  pid and empty options.

  Otherwise the second argument is interpreted as options. It delegates to
  `consume/3` with the caller's pid and the given options.
  """
  @spec consume(t, pid | opts) :: {:ok, t} |
                                  {:error, :already_consuming}
  def consume(queue, pid) when is_pid(pid), do: consume(queue, pid, [])
  def consume(queue, opts),                 do: consume(queue, self(), opts)

  @doc """
  Consumes messages from the given queue through its associated channel.

  When a queue is being consumed by a pid status messages and actual queue messages
  are sent to that pid as elixir messages.

  The format of that messages depends on the adapter. Because of this reason the
  `handle/2` function is provided. It asks the adapter whether the given message
  is a known AMQP message and returns it in a predictable format.
  See `Hare.Conn.Queue.handle/2` for more information.

  Each queue struct must be consumed by only one pid. For another pid to consume
  the same queue, another queue struct must be built.
  """
  @spec consume(t, pid, opts) :: {:ok, t} |
                                 {:error, :already_consuming}
  def consume(%Queue{consuming: true}, _pid, _opts) do
    {:error, :already_consuming}
  end
  def consume(%Queue{chan: chan, name: name} = queue, pid, opts)
  when is_pid(pid) do
    with {:ok, consumer_tag} <- do_consume(chan, name, pid, opts) do
      new_queue = %{queue | consuming:     true,
                            consuming_pid: pid,
                            consumer_tag:  consumer_tag}

      {:ok, new_queue}
    end
  end

  @doc """
  When a pid consumes a queue, it receives status messages and actual queue messages
  as elixir messages. The format of those messages depends on the adapter.

  This function provides a way to tell whether the received message is a known
  AMQP message.

  It can return 4 different values for a given message:

    * `{:consume_ok, meta}` - The process has been registered as a consumer and messages from the queue will be sent
    * `{:deliver, payload, meta}` - This is an actual queue message
    * `{:cancel_ok, meta}` - The process has been unregistered as a consumer
    * `{:cancel, meta}` - The process has been unexpectedly unregistered as a consumer by server
    * `:unknown - The message is not a known AMQP message
  """
  @spec handle(t, message :: term) :: {:consume_ok, meta} |
                                      {:deliver, payload, meta} |
                                      {:cancel_ok, meta} |
                                      {:cancel, meta} |
                                      {:return, payload, meta} |
                                      :unknown
  def handle(%Queue{chan: %{adapter: adapter}}, message),
    do: adapter.handle(message)

  @doc """
  It cancels message consumption if the queue is consuming.
  Otherwise it does nothing.
  """
  @spec cancel(t, opts) :: {:ok, t}
  def cancel(queue, opts \\ [])
  def cancel(%Queue{consuming: false} = queue, _opts) do
    {:ok, queue}
  end
  def cancel(%Queue{chan: chan, consumer_tag: tag} = queue, opts) do
    with :ok <- do_cancel(chan, tag, opts) do
      new_queue = %{queue | consuming:     false,
                            consuming_pid: nil,
                            consumer_tag:  nil}

      {:ok, new_queue}
    end
  end

  @doc """
  Purges all messages on the given queue
  """
  @spec purge(t) :: {:ok, info :: term}
  def purge(%Queue{chan: chan, name: name}) do
    %{given: given, adapter: adapter} = chan

    adapter.purge(given, name)
  end

  @doc """
  Deletes the given queue.
  """
  @spec delete(t) :: {:ok, info :: term}
  def delete(%Queue{chan: chan, name: name}, opts \\ []) do
    %{given: given, adapter: adapter} = chan

    adapter.delete_queue(given, name, opts)
  end

  @doc """
  Redeliver all unacknowledged messages from a specified queue.

  It delegates the given options to the underlying adapter. The format
  of these options depends on the adapter.
  """
  def recover(%Queue{chan: %{given: given, adapter: adapter}}, opts \\ []) do
    adapter.recover(given, opts)
  end

  defp do_consume(%{given: given, adapter: adapter}, name, pid, opts),
    do: adapter.consume(given, name, pid, opts)
  defp do_cancel(%{given: given, adapter: adapter}, tag, opts),
    do: adapter.cancel(given, tag, opts)
end
