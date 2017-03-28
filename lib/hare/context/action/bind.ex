defmodule Hare.Context.Action.Bind do
  @moduledoc """
  This module implements a `Hare.Context.Bind` behaviour to
  bind a queue to an exchange on the AMQP server.

  ## Config

  Configuration must be a `Keyword.t` with the following fields:

    * `:queue` - the queue name to bind
    * `:queue_from_export` - the key where the queue must be found in the exports map
    * `:exchange` - the exchange name to bind to
    * `:exchange_from_export` - the key where the exchange must be found in the exports map
    * `:opts` - (defaults to `[]`) the options to be given to the adapter
    * `:export_as` - (defaults to `nil`) the key to export a pair {queue, exchange} to

  In order for the bind action to work a queue and an exchange must be provided.

  To provide a queue, a queue name must be provided using the `:queue` option.
  But in order to ensure the queue already exists and it is declared as expected it
  is recommended to declare the queue in a previous step and export it to a key.
  To use the declared exchange, provide the `:queue_from_export` option with that
  key as its value.

  Exactly the same stands for the exchange. Provide the exchange name with the
  `:exchange` option or use an exported one with `:exchange_from_export`.

  The `:export_as` config allows the action to export a pair
  `{Hare.Core.Queue, Hare.Core.Exchange}` struct to be used later by other steps.

  ```
  alias Hare.Context.Action.Bind

  config = [queue_from_exports: :my_queue,
            exchange_from_exports: :my_exchange,
            opts: [routing_key: "my_key.*"]]

  exports = %{my_queue: Hare.Core.Queue{chan: chan, name: "foo"},
              my_exchange: Hare.Core.Exchange{chan: chan, name: "bar"}}

  Bind.run(chan, config, exports)
  # => {:ok, nil, %{}}
  ```
  """

  @typedoc "The action configuration"
  @type config :: [queue:                binary,
                   queue_from_export:    atom,
                   exchange:             binary,
                   exchange_from_export: atom,
                   opts:                 Keyword.t,
                   export_as:            atom]

  @behaviour Hare.Context.Action

  alias Hare.Core.Queue
  alias Hare.Context.Action.Shared

  def validate(config) do
    Shared.Binding.validate(config)
  end

  def run(chan, config, exports) do
    binding_fun = &Queue.bind/3

    Shared.Binding.run(binding_fun, chan, config, exports)
  end
end
