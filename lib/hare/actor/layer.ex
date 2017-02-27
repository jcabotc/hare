defmodule Hare.Actor.Layer do
  @type state  :: term
  @type reason :: any

  @type conn :: Hare.Core.Conn.t
  @type chan :: Hare.Core.Chan.t

  @type on_init :: {:ok, state} |
                   {:ok, state, timeout} |
                   :ignore |
                   {:stop, reason}

  @callback init(next, state) :: on_init
              when next: (state -> on_init)

  @type on_channel :: {:ok, chan, state} |
                      {:stop, reason, state}

  @callback channel(conn, next, state) :: on_channel
              when next: (state -> on_channel)

  @type on_declare :: {:ok, state} |
                      {:stop, reason, state}

  @callback declare(chan, next, state) :: on_declare
              when next: (state -> on_declare)

  @type on_call :: {:reply, reply :: term, state} |
                   {:reply, reply :: term, state, timeout | :hibernate} |
                   {:noreply, state} |
                   {:noreply, state, timeout | :hibernate} |
                   {:stop, reason, reply :: term, state} |
                   {:stop, reason, state}

  @callback handle_call(message :: term, GenServer.from, next, state) :: on_call
              when next: (state -> on_call)

  @type on_cast :: {:noreply, state} |
                   {:noreply, state, timeout | :hibernate} |
                   {:stop, reason, state}

  @callback handle_cast(message :: term, next, state) :: on_cast
              when next: (state -> on_cast)

  @type on_info :: {:noreply, state} |
                   {:noreply, state, timeout | :hibernate} |
                   {:stop, reason, state}

  @callback handle_info(message :: term, next, state) :: on_info
              when next: (state -> on_info)

  @callback terminate(reason, next, state) :: any
              when next: (state -> any)

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      @behaviour Hare.Actor.Layer

      def init(next, initial),
        do: next.(initial)

      def channel(_conn, next, state),
        do: next.(state)

      def declare(_chan, next, state),
        do: next.(state)

      def handle_call(_message, _from, next, state),
        do: next.(state)

      def handle_cast(_message, next, state),
        do: next.(state)

      def handle_info(_message, next, state),
        do: next.(state)

      def terminate(_reason, next, state),
        do: next.(state)

      defoverridable init:        2,
                     channel:     3,
                     declare:     3,
                     handle_call: 4,
                     handle_cast: 3,
                     handle_info: 3,
                     terminate:   3
    end
  end
end
