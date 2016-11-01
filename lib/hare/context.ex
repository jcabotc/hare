defmodule Hare.Context do
  alias Hare.Core.Chan
  alias __MODULE__.{Result, Action}

  @type steps :: Keyword.t

  @spec validate(steps) ::
          :ok |
          {:error, :not_a_keyword_list} |
          {:error, {:invalid_step, name :: atom, term}}
  def validate(steps) do
    case Keyword.keyword?(steps) do
      true  -> validate_each(steps)
      false -> {:error, :not_a_keyword_list}
    end
  end

  defp validate_each([]) do
    :ok
  end
  defp validate_each([{name, config} | rest]) do
    case Action.validate(name, config) do
      :ok              -> validate_each(rest)
      {:error, reason} -> {:error, {:invalid_step, name, reason}}
    end
  end

  @spec run(Chan.t, steps) ::
          {:invalid, term} |
          {:ok, Result.t} |
          {:error, Result.t}
  def run(%Chan{} = chan, steps) do
    case validate(steps) do
      :ok              -> run_each(chan, steps, Result.new)
      {:error, reason} -> {:invalid, reason}
    end
  end

  defp run_each(_chan, [], result) do
    {:ok, result}
  end
  defp run_each(chan, [step | rest], result) do
    case perform(chan, step, result) do
      {:ok,    new_result} -> run_each(chan, rest, new_result)
      {:error, new_result} -> set_not_done(rest, new_result)
    end
  end

  defp perform(chan, {name, config}, %{exports: exports} = result) do
    case Action.run(chan, name, config, exports) do
      :ok ->
        {:ok, Result.success(result, name, config, nil,  exports)}
      {:ok, info} ->
        {:ok, Result.success(result, name, config, info, exports)}
      {:ok, info, new_exports} ->
        {:ok, Result.success(result, name, config, info, new_exports)}
      {:error, reason} ->
        {:error, Result.failure(result, name, config, reason)}
    end
  end

  defp set_not_done([], result),
    do: {:error, result}
  defp set_not_done([{name, config} | rest], result),
    do: set_not_done(rest, Result.not_done(result, name, config))
end
