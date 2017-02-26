defmodule Hare.Support.TestExtension do
  use Hare.Role.Layer

  def handle_info({:test_extension, pid}, _next, state) do
    send(pid, :test_extension_success)
    {:noreply, state}
  end
  def handle_info(_message, next, state) do
    next.(state)
  end
end
