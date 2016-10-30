defmodule Hare.Declaration.Result do
  alias __MODULE__

  defstruct steps: [],
            tags:  %{}

  def new,
    do: %Result{}

  def steps(%Result{steps: steps}),
    do: Enum.reverse(steps)

  def success(%Result{} = result, name, config, info, new_tags),
    do: ok_step(name, config, info) |> add(result, new_tags)

  def failure(%Result{} = result, name, config, reason),
    do: error_step(name, config, reason) |> add(result)

  def not_done(%Result{} = result, name, config),
    do: not_done_step(name, config) |> add(result)

  defp ok_step(name, config, info),
    do: {name, %{status: :success, config: config, info: info}}

  defp error_step(name, config, reason),
    do: {name, %{status: :failure, config: config, reason: reason}}

  defp not_done_step(name, config),
    do: {name, %{status: :not_done, config: config}}

  defp add(step, %{steps: steps} = result) do
    %{result | steps: [step | steps]}
  end
  defp add(step, %{steps: steps, tags: tags} = result, new_tags) do
    %{result | steps: [step | steps], tags: new_tags}
  end
end
