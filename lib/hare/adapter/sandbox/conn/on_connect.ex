defmodule Hare.Adapter.Sandbox.Conn.OnConnect do
  def start_link(results, opts \\ []) do
    Agent.start_link(fn -> results end, opts)
  end

  def pop(on_connect) do
    Agent.get_and_update(on_connect, &do_pop/1)
  end

  defp do_pop([]) do
    {:ok, []}
  end
  defp do_pop([result | rest]) do
    {result, rest}
  end
end
