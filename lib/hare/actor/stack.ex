defmodule Hare.Actor.Stack do
  alias __MODULE__

  defstruct [:extensions, :mod]

  def new(extensions, mod) do
    %Stack{extensions: extensions, mod: mod}
  end

  def run(%Stack{extensions: extensions, mod: mod}, fun, args, state) do
    do_run(extensions, mod, fun, args, state)
  end

  defp do_run([], mod, fun, args, state) do
    apply(mod, fun, args ++ [state])
  end
  defp do_run([extension | rest], mod, fun, args, state) do
    next = &do_run(rest, mod, fun, args, &1)

    apply(extension, fun, args ++ [next, state])
  end
end
