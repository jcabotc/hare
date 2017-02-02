defmodule Hare.Adapter.Sandbox.Conn.Stack do
  @moduledoc false

  def start_link(items, opts \\ []),
    do: Agent.start_link(fn -> items end, opts)

  def pop(stack),
    do: Agent.get_and_update(stack, &do_pop/1)

  defp do_pop([]),
    do: {:empty, []}
  defp do_pop([result | rest]),
    do: {result, rest}
end
