defmodule Hare.Action.Helper.Validations do
  defmacro validate(config, field, format, opts \\ []) do
    guard          = :"is_#{format}"
    error_reason   = :"not_#{format}"
    on_not_present = not_present_clause(config, field, opts)

    quote location: :keep do
      case Keyword.fetch(unquote(config), unquote(field)) do
        {:ok, value} when unquote(guard)(value) ->
          :ok
        {:ok, value} ->
          {:error, {unquote(error_reason), unquote(field), value}}
        :error ->
          unquote(on_not_present)
      end
    end
  end

  defmacro validate_keyword(config, field, opts \\ []) do
    on_not_present = not_present_clause(config, field, opts)

    quote location: :keep do
      case Keyword.fetch(unquote(config), unquote(field)) do
        {:ok, value} ->
          case Keyword.keyword?(value) do
            true -> :ok
            false -> {:error, {:not_keyword_list, unquote(field), value}}
          end
        :error ->
          unquote(on_not_present)
      end
    end
  end

  defp not_present_clause(config, field, opts) do
    case Keyword.get(opts, :required, true) do
      true ->
        quote do: {:error, {:not_present, unquote(field), unquote(config)}}
      false ->
        quote do: :ok
    end
  end
end
