defmodule Hare.Core.Queue do
  alias __MODULE__
  alias Hare.Core.{Chan, Exchange}

  defstruct chan:          nil,
            name:          nil,
            consuming:     false,
            consuming_pid: nil,
            consumer_tag:  nil

  def new(%Chan{} = chan, name) when is_binary(name),
    do: %Queue{chan: chan, name: name}

  def declare(chan),
    do: declare(chan, [])
  def declare(chan, name) when is_binary(name),
    do: declare(chan, name, [])
  def declare(%Chan{} = chan, opts) do
    %{given: given, adapter: adapter} = chan

    with {:ok, name, info} <- adapter.declare_server_named_queue(given, opts) do
      {:ok, info, %Queue{chan: chan, name: name}}
    end
  end
  def declare(%Chan{} = chan, name, opts)
  when is_binary(name) do
    %{given: given, adapter: adapter} = chan

    with {:ok, info} <- adapter.declare_queue(given, name, opts) do
      {:ok, info, %Queue{chan: chan, name: name}}
    end
  end

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

  def get(%Queue{chan: chan, name: name}, opts \\ []) do
    %{given: given, adapter: adapter} = chan

    adapter.get(given, name, opts)
  end

  def ack(%Queue{chan: %{given: given, adapter: adapter}}, meta, opts \\ []),
    do: adapter.ack(given, meta, opts)
  def nack(%Queue{chan: %{given: given, adapter: adapter}}, meta, opts \\ []),
    do: adapter.nack(given, meta, opts)
  def reject(%Queue{chan: %{given: given, adapter: adapter}}, meta, opts \\ []),
    do: adapter.reject(given, meta, opts)

  def consume(queue),                       do: consume(queue, self, [])
  def consume(queue, pid) when is_pid(pid), do: consume(queue, pid, [])
  def consume(queue, opts),                 do: consume(queue, self, opts)
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

  def handle(%Queue{chan: %{adapter: adapter}}, message),
    do: adapter.handle(message)

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

  def purge(%Queue{chan: chan, name: name}) do
    %{given: given, adapter: adapter} = chan

    adapter.purge(given, name)
  end

  def delete(%Queue{chan: chan, name: name}, opts \\ []) do
    %{given: given, adapter: adapter} = chan

    adapter.delete_queue(given, name, opts)
  end

  defp do_consume(%{given: given, adapter: adapter}, name, pid, opts),
    do: adapter.consume(given, name, pid, opts)
  defp do_cancel(%{given: given, adapter: adapter}, tag, opts),
    do: adapter.cancel(given, tag, opts)
end
