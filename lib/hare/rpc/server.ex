# defmodule Hare.RPC.Server do
#   use Connection
#
#   alias __MODULE__.State
#
#   def start_link(mod, conn, config, initial, opts \\ []) do
#     GenServer.start_link(__MODULE__, {mod, conn, config, initial}, opts)
#   end
#
#   def init({mod, conn, config, initial}) do
#     state = State.new(mod, conn, config)
#
#     case State.init(state, initial) do
#       {:ok, new_state}          -> {:ok, new_state}
#       {:ok, new_state, timeout} -> {:ok, new_state, timeout}
#       {:consume, new_state}     -> {:connect, :init, new_state}
#       :ignore                   -> :ignore
#       {:stop, reason}           -> {:stop, reason}
#     end
#   end
#
#   def connect(_info, %{conn: conn, config: config} = state) do
#     case State.open_channel(state) do
#       {:ok, new_state} -> {:ok, new_state}
#       {:error, reason} -> {:stop, reason}
#     end
#   end
#
#   def disconnect(_info, state) do
#     new_state = State.close_channel(state)
#
#     {:stop, :normal, new_state}
#   end
# end

# defmodule Segmentator.RpcServer.V1.Segment do
#   alias Hare.RPC.Server, as: RPC
#   use RPC
#
#   def start_link(opts \\ []) do
#     RPC.start_link(__MODULE__, :ok, opts)
#   end
#
#   def init(:ok) do
#     {:ok, %{}}
#   end
#
#   def handle_message({payload, _meta}, state) do
#     response = do_something(payload)
#
#     {:reply, response, state}
#   end
#
#   def handle_message({payload, meta}, state) do
#     responder = &RPC.reply(meta, &1)
#     do_something(payload, responder)
#
#     {:noreply, state}
#   end
# end
