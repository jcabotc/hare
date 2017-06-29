defmodule Hare.Adapter.Sandbox do
  @moduledoc """
  Sandbox implementation for the `Hare.Adapter` behaviour.

  It is meant to be used only on tests.

  This adapter allows the developer to inspect its history and modify
  its behaviour during tests throught the `Hare.Adapter.Sandbox.Backdoor`
  module.

  Check `Hare.Adapter.Sandbox.Backdoor` for more information.
  """

  @behaviour Hare.Adapter

  alias __MODULE__.{Conn, Chan}

  # Connection
  #
  def open_connection(config) do
    with {:ok, conn} = result <- Conn.open(config) do
      register(conn, {:open_connection, [config], result})
    end
  end

  def monitor_connection(conn) do
    result = Conn.monitor(conn)
    register(conn, {:monitor_connection, [conn], result})
  end

  def close_connection(conn) do
    result = Conn.stop(conn)
    register(conn, {:close_connection, [conn], result})
  end

  # Channel
  #
  def open_channel(conn) do
    result = Chan.open(conn)
    register(conn, {:open_channel, [conn], result})
  end

  def monitor_channel(chan) do
    result = Chan.monitor(chan)
    register(chan, {:monitor_channel, [chan], result})
  end

  def link_channel(chan) do
    result = Chan.link(chan)
    register(chan, {:link_channel, [chan], result})
  end

  def unlink_channel(chan) do
    result = Chan.unlink(chan)
    register(chan, {:unlink_channel, [chan], result})
  end

  def qos(chan, opts) do
    register(chan, {:qos, [chan, opts], :ok})
  end

  def close_channel(chan) do
    result = Chan.close(chan)
    register(chan, {:close_channel, [chan], result})
  end

  # Declare
  #
  def declare_exchange(chan, exchange, type, opts) do
    register(chan, {:declare_exchange, [chan, exchange, type, opts], :ok})
  end

  def delete_exchange(chan, exchange, opts) do
    register(chan, {:delete_exchange, [chan, exchange, opts], :ok})
  end

  def declare_queue(chan, queue, opts) do
    register(chan, {:declare_queue, [chan, queue, opts], {:ok, %{}}})
  end

  def declare_server_named_queue(chan, opts) do
    name = "generated_name_#{:rand.uniform(10000)}"
    register(chan, {:declare_server_named_queue, [chan, opts], {:ok, name, %{}}})
  end

  def delete_queue(chan, queue, opts) do
    register(chan, {:delete_queue, [chan, queue, opts], {:ok, %{}}})
  end

  def bind(chan, queue, exchange, opts) do
    register(chan, {:bind, [chan, queue, exchange, opts], :ok})
  end

  def unbind(chan, queue, exchange, opts) do
    register(chan, {:unbind, [chan, queue, exchange, opts], :ok})
  end

  # Publish
  #
  def publish(chan, exchange, payload, routing_key, opts) do
    args = [chan, exchange, payload, routing_key, opts]
    register(chan, {:publish, args, :ok})
  end

  # Get
  #
  def get(chan, queue, opts) do
    result = case Chan.get_message(chan) do
      :empty  -> {:empty, %{}}
      payload -> {:ok, payload, :meta}
    end

    register(chan, {:get, [chan, queue, opts], result})
  end

  def purge(chan, queue) do
    register(chan, {:purge, [chan, queue], {:ok, %{}}})
  end

  def consume(chan, queue, pid, opts) do
    tag = "consumer_tag_#{:rand.uniform(10000)}"
    register(chan, {:consume, [chan, queue, pid, opts], {:ok, tag}})
  end

  def recover(chan, opts) do
    register(chan, {:recover, [chan, opts], :ok})
  end

  def register_return_handler(chan, pid) do
    register(chan, {:register_return_handler, [chan, pid], :ok})
  end

  def unregister_return_handler(chan) do
    register(chan, {:unregister_return_handler, [chan], :ok})
  end

  def handle({:consume_ok, _meta} = message),
    do: message
  def handle({:deliver, _payload, _meta} = message),
    do: message
  def handle({:cancel_ok, _meta} = message),
    do: message
  def handle({:cancel, _meta} = message),
    do: message
  def handle({:return, _payload, _meta} = message),
    do: message
  def handle(_message),
    do: :unknown

  def cancel(chan, consumer_tag, opts) do
    register(chan, {:cancel, [chan, consumer_tag, opts], :ok})
  end

  def ack(chan, meta, opts),
    do: register(chan, {:ack, [chan, meta, opts], :ok})

  def nack(chan, meta, opts),
    do: register(chan, {:nack, [chan, meta, opts], :ok})

  def reject(chan, meta, opts),
    do: register(chan, {:reject, [chan, meta, opts], :ok})

  # Helpers
  #
  defp register(%Conn{} = conn, event),
    do: Conn.register(conn, event)
  defp register(%Chan{} = conn, event),
    do: Chan.register(conn, event)
end
