defmodule Hare.Actor.StackTest do
  use ExUnit.Case, async: true

  alias Hare.Actor.Stack

  defmodule TestExtension1 do
    def foo(next, pid) do
      send(pid, {:ext1, :foo, pid})
      next.({pid, :foo})
    end

    def bar(arg1, arg2, _next, pid) do
      send(pid, {:ext1, :bar, arg1, arg2, pid})
      :ext1_bar_reply
    end
  end

  defmodule TestExtension2 do
    def foo(next, {pid, :foo}),
      do: next.(pid)

    def bar(_arg1, _arg2, _next, pid),
      do: send(pid, :ext2_called)
  end

  defmodule TestMod do
    def foo(_pid), do: :mod_foo_reply
  end

  test "new/2 and run/4" do
    extensions = [TestExtension1, TestExtension2]
    mod        = TestMod

    stack    = Stack.new(extensions, mod)
    test_pid = self()

    assert :mod_foo_reply == Stack.run(stack, :foo, [], test_pid)
    assert_receive {:ext1, :foo, ^test_pid}

    assert :ext1_bar_reply == Stack.run(stack, :bar, [1, 2], test_pid)
    assert_receive {:ext1, :bar, 1, 2, ^test_pid}
    refute_receive :ext2_called, 10
  end
end
