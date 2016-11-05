# defmodule Hare.RPC.Server.Context do
#   def parse(config) do
#     with {:ok, queue_config} <- Keyword.fetch(config, :queue),
#          {:ok, name}         <- Keyword.fetch(queue_config, :name),
#          {:ok, opts}         <- Keyword.get(queue_config, :opts, []) do
#       context_config(name, opts)
#     else
#       :error -> wrong_format_error(config)
#     end
#   end
#
#   def setup(chan, context_config) do
#     # case Context.run(chan, context_config) do
#     # end
#   end
#
#   defp context_config(name, opts) do
#     [queue: [
#       name: name,
#       opts: opts,
#       export_as: :queue]]
#   end
# end
