defmodule Hare.Publisher.Extension do
  alias Hare.Publisher

  @type payload     :: Publisher.payload
  @type routing_key :: Publisher.routing_key
  @type opts        :: Publisher.opts
  @type meta        :: Publisher.meta
  @type state       :: Publisher.state

  @doc """
  Called when the publisher process is first started. `start_link/5` will block
  until it returns.

  It receives as argument the fourth argument given to `start_link/5`.

  Returning `{:ok, state}` will cause `start_link/5` to return `{:ok, pid}`
  and attempt to open a channel on the given connection and declare the exchange.
  After that it will enter the main loop with `state` as its internal state.

  Returning `:ignore` will cause `start_link/5` to return `:ignore` and the
  process will exit normally without entering the loop, opening a channel or calling
  `terminate/2`.

  Returning `{:stop, reason}` will cause `start_link/5` to return `{:error, reason}` and
  the process will exit with reason `reason` without entering the loop, opening a channel,
  or calling `terminate/2`.
  """
  @callback init(next, initial :: term) ::
    Publisher.on_init when next: (state -> Publisher.on_init)

  @doc """
  Called before a message will be published to the exchange.

  It receives as argument the message payload, the routing key, the options
  for that publication and the internal state.

  Returning `{:ok, state}` will cause the message to be sent with no
  modification, and enter the main loop with the given state.

  Returning `{:ok, payload, routing_key, opts, state}` will cause the
  given payload, routing key and options to be used instead of the original
  ones, and enter the main loop with the given state.

  Returning `{:ignore, state}` will ignore that message and enter the main loop
  again with the given state.

  Returning `{:stop, reason, state}` will not send the message, terminate the
  main loop and call `terminate(reason, state)` before the process exists with
  reason `reason`.
  """
  @callback before_publication(payload, routing_key, opts :: term, next, state) ::
    Publisher.on_before_publication when next: Publisher.on_before_publication

  @doc """
  Called after a message has been published to the exchange.

  It receives as argument the message payload, the routing key, the options
  for that publication and the internal state.

  Returning `{:ok, state}` will enter the main loop with the given state.

  Returning `{:stop, reason, state}` will terminate the
  main loop and call `terminate(reason, state)` before the process exists with
  reason `reason`.
  """
  @callback after_publication(payload, routing_key, opts :: term, next, state) ::
    Publisher.on_after_publication when next: (state -> Publisher.on_after_publication)

  @doc """
  Called when the process receives a message.

  Returning `{:noreply, state}` will causes the process to enter the main loop
  with the given state.

  Returning `{:stop, reason, state}` will not send the message, terminate the
  main loop and call `terminate(reason, state)` before the process exists with
  reason `reason`.
  """
  @callback handle_info(message :: term, next, state) ::
    Publisher.on_handle_info when next: Publisher.on_handle_info

  @doc """
  This callback is the same as the `GenServer` equivalent and is called when the
  process terminates. The first argument is the reason the process is about
  to exit with.
  """
  @callback terminate(reason :: term, next, state) ::
    Publisher.on_terminate when next: Publisher.on_terminate

  defmacro __using__(opts \\ []) do
    quote location: :keep do
      @behaviour Hare.Publisher.Extension

      @doc false
      def init(next, initial),
        do: next.(initial)

      @doc false
      def before_publication(_payload, _routing_key, _meta, next, state),
        do: next.(state)

      @doc false
      def after_publication(_payload, _routing_key, _meta, next, state),
        do: next.(state)

      @doc false
      def handle_call(_message, _from, next, state),
        do: next.(state)

      @doc false
      def handle_cast(_message, next, state),
        do: next.(state)

      @doc false
      def handle_info(_message, next, state),
        do: next.(state)

      @doc false
      def terminate(_reason, next, state),
        do: next.(state)

      defoverridable [init: 2, terminate: 3,
                      before_publication: 5, after_publication: 5,
                      handle_call: 4, handle_cast: 3, handle_info: 3]
    end
  end
end
