defmodule Hare.Adapter.Sandbox.Conn do
  alias __MODULE__
  alias __MODULE__.{Pid, History}

  defstruct [:pid, :history]

  def open(config) do
    {:ok, pid} = Pid.start_link
    history    = get_history(config)

    {:ok, %Conn{pid: pid, history: history}}
  end

  def monitor(%Conn{pid: pid}) do
    Process.monitor(pid)
  end

  def link(%Conn{pid: pid}) do
    Process.link(pid)
  end

  def stop(%Conn{pid: pid}, reason \\ :normal) do
    Pid.stop(pid, reason)
  end

  def register(%Conn{history: history}, event) do
    History.push(history, event)
  end

  defp get_history(config) do
    case Keyword.fetch(config, :history) do
      {:ok, history} -> history
      :error         -> build_history
    end
  end

  defp build_history do
    case History.start_link do
      {:ok, history}   -> history
      {:error, reason} -> raise "Could not start history: #{inspect reason}"
    end
  end
end
