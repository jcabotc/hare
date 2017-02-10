defmodule Hare.RPC.Client.Runtime do
  @moduledoc false

  alias __MODULE__

  defstruct [:timeout]

  @default_timeout 5000

  def parse(config) do
    with {:ok, timeout} <- get_timeout(config) do
      {:ok, %Runtime{timeout: timeout}}
    end
  end

  defp get_timeout(config) do
    case Keyword.fetch(config, :timeout) do
      {:ok, timeout} when is_integer(timeout) and timeout > 0 ->
        {:ok, timeout}
      {:ok, :infinity} ->
        {:ok, :infinity}
      {:ok, timeout} ->
        {:error, {:not_integer_or_infinity_timeout, timeout}}
      :error ->
        {:ok, @default_timeout}
    end
  end
end
