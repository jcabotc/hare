defmodule Hare.Adapter.Sandbox.Conn.History do
  def start_link(opts \\ []) do
    Agent.start_link(fn -> [] end, opts)
  end

  def push(history, {_function, _args, result} = event) do
    Agent.update(history, &[event | &1])
    result
  end

  def events(history) do
    Agent.get(history, &(&1)) |> Enum.reverse
  end
end
