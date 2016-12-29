defmodule Hare.RPC.Client do
  @type payload     :: binary
  @type routing_key :: binary
  @type meta        :: map
  @type state       :: term

  @callback init(initial :: term) ::
              GenServer.on_start

  @callback connected(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @callback handle_ready(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @callback handle_request(payload, routing_key, opts :: term, state) ::
              {:ok, state} |
              {:ok, payload, routing_key, opts :: term, state} |
              {:reply, response :: term, state} |
              {:stop, reason :: term, response :: binary, state}

  @callback handle_info(meta, state) ::
              {:noreply, state} |
              {:stop, reason :: term, state}

  @callback terminate(reason :: term, state) ::
              any

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      @behaviour Hare.RPC.Client

      def init(initial),
        do: {:ok, initial}

      def connected(_meta, state),
        do: {:noreply, state}

      def handle_ready(_meta, state),
        do: {:noreply, state}

      def handle_request(_payload, _routing_key, _meta, state),
        do: {:ok, state}

      def handle_info(_message, state),
        do: {:noreply, state}

      def terminate(_reason, _state),
        do: :ok

      defoverridable [init: 1, terminate: 2, connected: 2,
                      handle_ready: 2, handle_request: 4, handle_info: 2]
    end
  end

  use Connection

  alias __MODULE__.{Declaration, State}
  alias Hare.Core.{Chan, Queue, Exchange}

  @context Hare.Context

  def start_link(mod, conn, config, initial, opts \\ []) do
    {context, opts} = Keyword.pop(opts, :context, @context)
    args = {mod, conn, config, context, initial}

    Connection.start_link(__MODULE__, args, opts)
  end

  def request(client, payload, routing_key \\ "", opts \\ []),
    do: Connection.call(client, {:request, payload, routing_key, opts})

  def init({mod, conn, config, context, initial}) do
    with {:ok, declaration} <- Declaration.parse(config, context),
         {:ok, given}       <- mod.init(initial) do
      {:connect, :init, State.new(conn, declaration, mod, given)}
    else
      {:error, reason} -> {:stop, {:config_error, reason, config}}
      other            -> other
    end
  end

  def connect(_info, %{conn: conn, declaration: declaration} = state) do
    with {:ok, chan}                     <- Chan.open(conn),
         {:ok, resp_queue, req_exchange} <- Declaration.run(declaration, chan),
         {:ok, new_resp_queue}           <- Queue.consume(resp_queue) do
      handle_connected(state, chan, new_resp_queue, req_exchange)
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  defp handle_connected(%{mod: mod, given: given} = state, chan, resp_queue, req_exchange) do
    ref  = Chan.monitor(chan)
    meta = complete(%{}, state)

    case mod.connected(meta, given) do
      {:noreply, new_given} ->
        {:ok, State.connected(state, chan, ref, resp_queue, req_exchange, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.connected(state, chan, ref, resp_queue, req_exchange, new_given)}
    end
  end

  def disconnect(_info, state),
    do: {:stop, :normal, state}

  def handle_call({:request, payload, routing_key, opts}, from, %{mod: mod, given: given} = state) do
    case mod.handle_request(payload, routing_key, opts, given) do
      {:ok, new_given} ->
        correlation_id = perform(payload, routing_key, opts, state)
        {:noreply, State.set(state, new_given, correlation_id, from)}

      {:ok, new_payload, new_opts, new_given} ->
        correlation_id = perform(new_payload, routing_key, new_opts, state)
        {:noreply, State.set(state, new_given, correlation_id, from)}

      {:reply, response, new_given} ->
        {:reply, response, State.set(state, new_given)}

      {:stop, reason, response, new_given} ->
        {:stop, reason, response, State.set(state, new_given)}
    end
  end

  def handle_info({:DOWN, ref, _, _, _reason}, %{status: :connected, ref: ref} = state) do
    {:connect, :down, State.chan_down(state)}
  end
  def handle_info(message, %{status: :connected, resp_queue: queue} = state) do
    case Queue.handle(queue, message) do
      {:consume_ok, meta} ->
        handle_mod_ready(meta, state)

      {:deliver, payload, meta} ->
        handle_response(payload, meta, state)

      {:cancel_ok, _meta} ->
        {:stop, :cancelled, state}

      :unknown ->
        handle_mod_info(message, state)
    end
  end
  def handle_info(message, state) do
    handle_mod_info(message, state)
  end

  def terminate(reason, %{status: :connected, chan: chan} = state) do
    mod_terminate(reason, state)
    Chan.close(chan)
  end
  def terminate(reason, state) do
    mod_terminate(reason, state)
  end

  defp mod_terminate(reason, %{mod: mod, given: given}),
    do: mod.terminate(reason, given)

  defp handle_mod_ready(meta, %{mod: mod, given: given} = state) do
    case mod.handle_ready(complete(meta, state), given) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  defp handle_response(payload, %{correlation_id: correlation_id}, state) do
    case State.pop_waiting(state, correlation_id) do
      {:ok, from, new_state} ->
        GenServer.reply(from, payload)
        {:noreply, new_state}

      :unknown ->
        {:noreply, state}
    end
  end

  defp handle_mod_info(message, %{mod: mod, given: given} = state) do
    case mod.handle_info(message, given) do
      {:noreply, new_given} ->
        {:noreply, State.set(state, new_given)}

      {:stop, reason, new_given} ->
        {:stop, reason, State.set(state, new_given)}
    end
  end

  defp perform(payload, routing_key, opts, %{req_exchange: req_exchange, resp_queue: resp_queue}) do
    correlation_id = generate_correlation_id
    new_opts = Keyword.merge(opts, reply_to:       resp_queue.name,
                                   correlation_id: correlation_id)

    Exchange.publish(req_exchange, payload, routing_key, new_opts)
    correlation_id
  end

  defp generate_correlation_id do
    :erlang.unique_integer
    |> :erlang.integer_to_binary
    |> Base.encode64
  end

  defp complete(meta, %{resp_queue: resp_queue, req_exchange: req_exchange}) do
    meta
    |> Map.put(:req_exchange, req_exchange)
    |> Map.put(:resp_queue, resp_queue)
  end
end
