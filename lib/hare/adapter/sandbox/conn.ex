defmodule Hare.Adapter.Sandbox.Conn do
  @moduledoc false

  alias __MODULE__
  alias __MODULE__.{Pid, History, Stack}

  defstruct [:pid, :history, :on_channel_open, :messages]

  def open(config) do
    case Keyword.fetch(config, :on_connect) do
      {:ok, on_connect} -> handle_on_connect(on_connect, config)
      :error            -> {:ok, new(config)}
    end
  end

  def monitor(%Conn{pid: pid}),
    do: Process.monitor(pid)

  def link(%Conn{pid: pid}),
    do: Process.link(pid)

  def unlink(%Conn{pid: pid}),
    do: Process.unlink(pid)

  def stop(%Conn{pid: pid}, reason \\ :normal),
    do: Pid.stop(pid, reason)

  def register(%Conn{history: history}, event),
    do: History.push(history, event)

  def on_channel_open(%Conn{on_channel_open: nil}),
    do: :ok
  def on_channel_open(%Conn{on_channel_open: on_channel_open}),
    do: with(:empty <- Stack.pop(on_channel_open), do: :ok)

  def get_message(%Conn{messages: messages}),
    do: Stack.pop(messages)

  defp handle_on_connect(on_connect, config) do
    with value when value in [:ok, :empty] <- Stack.pop(on_connect) do
      {:ok, new(config)}
    end
  end

  defp new(config) do
    {:ok, pid}      = Pid.start_link
    history         = get_or_create_history(config)
    on_channel_open = Keyword.get(config, :on_channel_open, nil)
    messages        = Keyword.get(config, :messages, [])

    %Conn{pid:             pid,
          history:         history,
          on_channel_open: on_channel_open,
          messages:        messages}
  end

  defp get_or_create_history(config) do
    case Keyword.fetch(config, :history) do
      {:ok, history} -> history
      :error         -> History.start_link |> elem(1)
    end
  end
end
