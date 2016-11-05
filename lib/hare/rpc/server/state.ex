# defmodule Hare.RPC.Server.State do
#   alias __MODULE__
#
#   defstruct mod:     nil,
#             conn:    nil,
#             config:  nil,
#             given:   nil
#
#   def new(mod, conn, config) when is_atom(mod) do
#     %State{mod: mod, conn: conn, config: config}
#   end
#
#   def set(%State{} = state, given) do
#     %{state | given: given}
#   end
# end
