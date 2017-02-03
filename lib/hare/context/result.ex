defmodule Hare.Context.Result do
  @moduledoc """
  This module defines the `Hare.Context.Result` that represents the result
  of a ran set of steps.

  It contains the following fields:

    * `steps` - A list of maps that represent the result of each step
    * `exports` - The data exported by the context

  ## Steps

  The steps field keeps information about all steps in inverse order. The `steps/1`
  function is provided to return them in the proper order.

  Each step may have one of the following formats:

    1. On success: `%{status: :success, config: step_config, info: info}`
    2. On failure: `%{status: :failure, config: step_config, reason: reason}`
    3. When not run: `%{status: :not_done, config: step_config}`
  """

  alias __MODULE__

  @type step_mod :: Hare.Context.Action.t
  @type config   :: Hare.Context.Action.config
  @type info     :: Hare.Context.Action.info
  @type exports  :: Hare.Context.Action.exports

  @typedoc """
  The possible formats of a step depending on whether it succeeded, failed or
  was not run.
  """
  @type step_result :: %{status: :success, config: config, info: info} |
                       %{status: :failure, config: config, reason: reason :: term} |
                       %{status: :not_done, config: config}

  @typedoc "A list of pairs {module, result} representing a step."
  @type steps :: [{step_mod, step_result}]

  @type t :: %__MODULE__{
              steps:   [{step_mod, step_result}],
              exports: exports}

  defstruct steps:   [],
            exports: %{}

  @doc "Creates a new empty result."
  @spec new() :: t
  def new,
    do: %Result{}

  @doc "Returns the step results in the order they ran in."
  @spec steps(t) :: steps
  def steps(%Result{steps: steps}),
    do: Enum.reverse(steps)

  @doc "Adds a success step to the given result, and updates exports."
  @spec success(t, step_mod, config, info, exports) :: t
  def success(%Result{} = result, mod, config, info, new_exports),
    do: ok_step(mod, config, info) |> add(result, new_exports)

  @doc "Adds a failure step to the given result."
  @spec failure(t, step_mod, config, reason :: term) :: t
  def failure(%Result{} = result, mod, config, reason),
    do: error_step(mod, config, reason) |> add(result)

  @doc "Adds a not_done step to the given result."
  @spec not_done(t, step_mod, config) :: t
  def not_done(%Result{} = result, mod, config),
    do: not_done_step(mod, config) |> add(result)

  defp ok_step(mod, config, info),
    do: {mod, %{status: :success, config: config, info: info}}

  defp error_step(mod, config, reason),
    do: {mod, %{status: :failure, config: config, reason: reason}}

  defp not_done_step(mod, config),
    do: {mod, %{status: :not_done, config: config}}

  defp add(step, %{steps: steps} = result) do
    %{result | steps: [step | steps]}
  end
  defp add(step, %{steps: steps} = result, new_exports) do
    %{result | steps: [step | steps], exports: new_exports}
  end
end
