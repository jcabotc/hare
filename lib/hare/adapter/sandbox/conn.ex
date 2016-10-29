defmodule Hare.Adapter.Sandbox.Conn do
  alias __MODULE__
  alias __MODULE__.{Pid, History, Stack}

  defstruct [:pid, :history, :on_channel_open]

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
    do: Stack.pop(on_channel_open)

  defp handle_on_connect(on_connect, config) do
    case Stack.pop(on_connect) do
      :ok   -> {:ok, new(config)}
      other -> other
    end
  end

  defp new(config) do
    {:ok, pid}      = Pid.start_link
    history         = Keyword.get(config, :history, nil)
    on_channel_open = Keyword.get(config, :on_channel_open, nil)

    %Conn{pid:             pid,
          history:         history,
          on_channel_open: on_channel_open}
  end
end
