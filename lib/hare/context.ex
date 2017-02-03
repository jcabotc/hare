defmodule Hare.Context do
  @moduledoc """
  This module provides an interface to run a set of declarations, bindings,
  deletions and other actions on a AMQP server.

  It is useful to setup a context before publishing or consuming messages by
  performing a set of actions, like declaring exchanges or binding queues. But
  it can also be used on its own.

  ## Actions

  Each step of the context is an action, and implements the `Hare.Context.Action`
  behaviour. All steps are run sequentially, and if one step fails no more steps are
  run.

  When running an action it receives a channel, a configuration for that action,
  and the exports map. The exports map is useful to put data on it to be accessed
  by future actions or to read data from past actions that took place.

  There are some common predefined actions that can be referenced by an atom,
  but custom ones can be supplied. Check `Hare.Context.Action` for more information
  on the default actions.

  ## Running a context

  A context receives a set of steps that has the following format:

  ```
  steps = [
    AnAction, [some: "config"],
    AnotherAction, [another: "action", foo: "bar"]
  ]

  {:ok, result} = Hare.Context.run(chan, steps)
  ```

  It returns a `Hare.Context.Result` struct keeps information and exports of
  run steps, and error reasons from a failed step if exists.
  Check `Hare.Context.Result` for more information.
  """

  alias Hare.Core.Chan
  alias __MODULE__.{Result, Action}

  @type steps :: Keyword.t

  @doc """
  Validates the format of a set of steps.
  """
  @spec validate(steps) ::
          :ok |
          {:error, :not_a_keyword_list} |
          {:error, {:invalid_step, step :: atom, term}}
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

  @doc """
  Runs a set of steps.

  It receives a channel to run the steps on, the set of steps, and
  some options.

  The only valid option is:

    * `:validate` - (true by default) Validates the steps before running them.

  It may return:

    * `{:invalid, reason}` - A step failed its validation
    * `{:ok, result}` - All steps validated and ran successfully
    * `{:error, result}` - A step failed to run
  """
  @spec run(Chan.t, steps, opts :: Keyword.t) ::
          {:invalid, term} |
          {:ok, Result.t} |
          {:error, Result.t}
  def run(%Chan{} = chan, steps, opts \\ []) do
    case Keyword.get(opts, :validate, true) do
      true  -> validate_and_run_each(chan, steps)
      false -> run_each(chan, steps)
    end
  end

  defp validate_and_run_each(chan, steps) do
    case validate(steps) do
      :ok              -> run_each(chan, steps)
      {:error, reason} -> {:invalid, reason}
    end
  end

  defp run_each(chan, steps, result \\ Result.new)
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
