defmodule Hare.Action.Helper.Tag do
  def get(tags, tag) do
    case Map.fetch(tags, tag) do
      {:ok, tag} -> {:ok, tag}
      :error     -> {:error, {:tag_missing, tag, tags}}
    end
  end

  def get_through(config, tags, field) do
    get(tags, Keyword.fetch!(config, field))
  end
end
