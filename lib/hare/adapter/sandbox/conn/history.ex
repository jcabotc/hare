defmodule Hare.Adapter.Sandbox.Conn.History do
  def start_link(opts \\ []) do
    Agent.start_link(fn -> [] end, opts)
  end

  def push(nil, {_function, _args, result}) do
    result
  end
  def push(history, {_function, _args, result} = event) do
    Agent.update(history, &[event | &1])
    result
  end

  def events(nil) do
    :no_history_given
  end
  def events(history) do
    Agent.get(history, &(&1)) |> Enum.reverse
  end

  def last_event(nil) do
    :no_history_given
  end
  def last_event(history) do
    Agent.get(history, &hd/1)
  end

  def last_events(nil, _count) do
    :no_history_given
  end
  def last_events(history, count) do
    history
    |> Agent.get(&Enum.take(&1, count))
    |> Enum.reverse
  end
end
