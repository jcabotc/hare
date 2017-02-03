defmodule Hare.Adapter.Sandbox.Backdoor do
  @moduledoc """
  This module provides the developer functions to
  use the sandbox adapter capabilities to inspect its history
  and modify its behaviour.
  """

  alias Hare.Adapter.Sandbox.{Conn, Chan}

  @doc """
  Starts a new history process and links it to the caller.

  This history process can be given to the adapter as the connection
  configuration.

  After that, functions like `events/1`, `last_event/1` and `last_events/2`
  can be used to retrieve information about how the adapter has been
  used.

  ```
  alias Hare.Adapter.Sandbox, as: Adapter

  {:ok, history} = Adapter.Backdoor.start_history()
  {:ok, conn} = Adapter.open_connection(history: history)

  # ... use the adapter

  Adapter.Backdoor.events(history) # => a list of events
  ```
  """
  @spec start_history(GenServer.options) :: Agent.on_start
  def start_history(opts \\ []),
    do: Conn.History.start_link(opts)

  @typedoc "Possible result specifications for `on_connect/1` and `on_channel_open/1`"
  @type result  :: :ok | {:error, reason :: term}

  @doc """
  Starts a new agent process that specifies the behaviour of the
  adapter when it opens a new connection.

  The first argument is a list of expected results when a new connection
  is open.

  The possible values of the results list are:

    * `:ok` - the connection opens successfully
    * `{:error, reason}` - the connection fails with the given reason

  The on_connect process can be given to the adapter as the connection
  configuration.

  ```
  alias Hare.Adapter.Sandbox, as: Adapter

  results = [{:error, :foo}, :ok, {:error, {:foo, "bar"}}, :ok]

  {:ok, on_connect} = Adapter.Backdoor.on_connect(results)
  config = [on_connect: on_connect]

  Adapter.open_connection(config) # => {:error, :foo}
  Adapter.open_connection(config) # => {:ok, conn_1}
  Adapter.open_connection(config) # => {:error, {:foo, "bar"}}
  Adapter.open_connection(config) # => {:ok, conn_2}
  Adapter.open_connection(config) # => {:ok, conn_3}
  ```
  """
  @spec on_connect([result], GenServer.options) :: Agent.on_start
  def on_connect(results, opts \\ []),
    do: Conn.Stack.start_link(results, opts)

  @doc """
  Starts a new agent process that specifies the behaviour of the
  adapter when it opens a new channel.

  The first argument is a list of expected results when a new channel
  is open.

  The possible values of the results list are:

    * `:ok` - the channel opens successfully
    * `{:error, reason}` - the channel fails with the given reason

  The on_channel_open process can be given to the adapter as the connection
  configuration.

  ```
  alias Hare.Adapter.Sandbox, as: Adapter

  results = [{:error, :foo}, :ok, {:error, {:foo, "bar"}}, :ok]

  {:ok, on_channel_open} = Adapter.Backdoor.on_channel_open(results)
  config = [on_channel_open: on_channel_open]

  {:ok, conn} = Adapter.open_connection(config)

  Adapter.open_channel(conn) # => {:error, :foo}
  Adapter.open_channel(conn) # => {:ok, chan_1}
  Adapter.open_channel(conn) # => {:error, {:foo, "bar"}}
  Adapter.open_channel(conn) # => {:ok, chan_2}
  Adapter.open_channel(conn) # => {:ok, chan_3}
  ```
  """
  @spec on_channel_open([result], GenServer.options) :: Agent.on_start
  def on_channel_open(results, opts \\ []),
    do: Conn.Stack.start_link(results, opts)

  @doc """
  Starts a new agent process that specifies the messages to be given when
  messages are get from a queue using `get/2`.

  Take into account that the sandbox adapter's `handle/2` function expects
  AMQP known messages to have the following format:

    * `{:consume_ok, meta}` - for the `consume-ok` message
    * `{:deliver, payload, meta}` - for an actual queue message
    * `{:cancel_ok, meta}` - for the `cancel-ok` message

  Anything else will cause `handle/2` to return `:unknown`.

  The messages process can be given to the adapter as the connection
  configuration.

  ```
  alias Hare.Adapter.Sandbox, as: Adapter

  raw_messages = [{:deliver, "foo", %{}},
                  {:deliver, "bar", %{}}]

  {:ok, messages} = Adapter.Backdoor.messages(results)

  {:ok, conn} = Adapter.open_connection(messages: messages)
  {:ok, chan} = Adapter.open_channel(conn)

  Adapter.get(chan, "one_queue")     # => {:ok, "foo", %{}}
  Adapter.get(chan, "another_queue") # => {:ok, "bar", %{}}
  Adapter.get(chan, "yet_another")   # => {:empty, %{}}
  ```
  """
  @spec messages(messages :: [term], GenServer.options) :: Agent.on_start
  def messages(messages, opts \\ []),
    do: Conn.Stack.start_link(messages, opts)

  @typedoc "Event returned by history checking functions. Like `events/1`."
  @type event  :: {function :: atom, args :: [term], result :: term}

  @doc """
  Returns all functions called on the adapter for the connection that
  was open with the given history on its configuration.

  Each event has the following format: `{function_name, arguments, result}`

  ```
  alias Hare.Adapter.Sandbox, as: Adapter

  {:ok, history} = Adapter.Backdoor.start_history()
  {:ok, conn} = Adapter.open_connection(history: history)

  {:ok, conn} = Adapter.open_connection(config)
  {:ok, chan} = Adapter.open_channel(conn)

  Adapter.get(chan, "my_queue", []) # => {:empty, %{}}

  Adapter.Backdoor.events(history) # => [{:open_connection, [history: history],     {:ok, conn}},
                                   #     {:open_channel,    [conn],                 {:ok, chan}},
                                   #     {:get,             [chan, "my_queue", []], {:empty, %{}}]
  ```
  """
  @spec events(pid) :: [event]
  def events(history),
    do: Conn.History.events(history)

  @doc """
  Similar to `events/1` but it only returns the most recent event.
  """
  @spec last_event(pid) :: event
  def last_event(history),
    do: Conn.History.last_event(history)

  @doc """
  Similar to `events/1` but it only returns the most recent `count` events.
  """
  @spec last_events(pid, count :: non_neg_integer) :: [event]
  def last_events(history, count),
    do: Conn.History.last_events(history, count)

  @doc """
  Unlinks a connection or a channel from the caller.

  Mainly used to avoid the test crashing because of a simulated crash of
  a connection or a channel.
  """
  @spec unlink(Conn.t | Chan.t) :: true
  def unlink(%Conn{} = conn),
    do: Conn.unlink(conn)
  def unlink(%Chan{} = chan),
    do: Chan.unlink(chan)


  @doc """
  Provokes a connection or a channel process to stop with the given reason,
  therefore triggering all monitors and links with that process.
  """
  @spec unlink(Conn.t | Chan.t) :: true
  def crash(resource, reason \\ :simulated_crash)

  def crash(%Conn{} = conn, reason),
    do: Conn.stop(conn, reason)
  def crash(%Chan{} = chan, reason),
    do: Chan.close(chan, reason)
end
