# Hare

Tools and abstractions to manage AMQP stuff.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `hare` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:hare, "~> 0.1.6"}]
    end
    ```

  2. Ensure `hare` is started before your application:

    ```elixir
    def application do
      [applications: [:hare]]
    end
    ```

