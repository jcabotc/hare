defmodule Hare.Context.Action.Qos do
  @moduledoc """
  This module implements a `Hare.Context.Action` behaviour to
  declare a qos.

  ## Config

  Configuration must be a `Keyword.t` with the following fields:

    * `:prefetch_count` - the number of messages to prefetch
  """

  @typedoc "The action configuration"
  @type config :: [prefetch_count: integer]

  @behaviour Hare.Context.Action

  alias Hare.Context.Action.Shared
  alias Hare.Core.Chan

  import Hare.Context.Action.Helper.Validations,
    only: [validate: 4]

  def validate(config) do
    validate(config, :prefetch_count, :integer, required: true)
  end

  def run(chan, config, exports) do
    Chan.qos(chan, prefetch_count: config[:prefetch_count])
  end
end
