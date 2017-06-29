if Code.ensure_loaded?(AMQP) do

  defmodule Hare.Adapter.AMQP do
    @moduledoc """
    Implementation of the `Hare.Adapter` behaviour for the AMQP library.

    Check `Hare.Adapter` for more information on the functions on this module.
    """

    @behaviour Hare.Adapter

    alias AMQP.{Connection,
                Channel,
                Exchange,
                Queue,
                Basic}

    # Connection
    #
    def open_connection(config) do
      Connection.open(config)
    end

    def monitor_connection(%Connection{pid: pid}) do
      Process.monitor(pid)
    end

    def close_connection(%Connection{} = conn) do
      Connection.close(conn)
      :ok
    end

    # Channel
    #
    def open_channel(%Connection{} = conn) do
      Channel.open(conn)
    end

    def monitor_channel(%Channel{pid: pid}) do
      Process.monitor(pid)
    end

    def link_channel(%Channel{pid: pid}) do
      Process.link(pid)
    end

    def unlink_channel(%Channel{pid: pid}) do
      Process.unlink(pid)
    end

    def qos(%Channel{} = chan, opts) do
      Basic.qos(chan, opts)
    end

    def close_channel(%Channel{} = chan) do
      Channel.close(chan)
      :ok
    end

    # Declare
    #
    def declare_exchange(%Channel{} = chan, name, type, opts \\ []) do
      Exchange.declare(chan, name, type, opts)
    end

    def delete_exchange(%Channel{} = chan, exchange, opts) do
      Exchange.delete(chan, exchange, opts)
    end

    def declare_queue(%Channel{} = chan, name, opts \\ []) do
      Queue.declare(chan, name, opts)
    end

    def declare_server_named_queue(%Channel{} = chan, opts \\ []) do
      with {:ok, %{queue: name} = result} <- Queue.declare(chan, "", opts) do
        {:ok, name, result}
      end
    end

    def delete_queue(%Channel{} = chan, queue, opts) do
      Queue.delete(chan, queue, opts)
    end

    def bind(%Channel{} = chan, queue, exchange, opts) do
      Queue.bind(chan, queue, exchange, opts)
    end

    def unbind(%Channel{} = chan, queue, exchange, opts) do
      Queue.unbind(chan, queue, exchange, opts)
    end

    # Publish
    #
    def publish(%Channel{} = chan, exchange, payload, routing_key, opts) do
      Basic.publish(chan, exchange, routing_key, payload, opts)
    end

    # Get
    #
    def get(%Channel{} = chan, queue, opts) do
      Basic.get(chan, queue, opts)
    end

    def purge(%Channel{} = chan, queue) do
      Queue.purge(chan, queue)
    end

    def consume(%Channel{} = chan, queue, pid, opts) do
      Basic.consume(chan, queue, pid, opts)
    end

    def recover(%Channel{} = chan, opts) do
      Basic.recover(chan, opts)
    end

    def register_return_handler(%Channel{} = chan, pid) do
      Basic.return(chan, pid)
    end

    def unregister_return_handler(%Channel{} = chan) do
      Basic.cancel_return(chan)
    end

    def handle({:basic_consume_ok, meta}),
      do: {:consume_ok, meta}
    def handle({:basic_deliver, payload, meta}),
      do: {:deliver, payload, meta}
    def handle({:basic_cancel_ok, meta}),
      do: {:cancel_ok, meta}
    def handle({:basic_cancel, meta}),
      do: {:cancel, meta}
    def handle({:basic_return, payload, meta}),
      do: {:return, payload, meta}
    def handle(_message),
      do: :unknown

    def cancel(%Channel{} = chan, consumer_tag, opts) do
      with {:ok, ^consumer_tag} <- Basic.cancel(chan, consumer_tag, opts) do
        :ok
      end
    end

    def ack(%Channel{} = chan, %{delivery_tag: tag}, opts),
      do: Basic.ack(chan, tag, opts)

    def nack(%Channel{} = chan, %{delivery_tag: tag}, opts),
      do: Basic.nack(chan, tag, opts)

    def reject(%Channel{} = chan, %{delivery_tag: tag}, opts),
      do: Basic.reject(chan, tag, opts)
  end

end
