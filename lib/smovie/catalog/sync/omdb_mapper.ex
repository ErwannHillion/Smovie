defmodule Smovie.Catalog.Sync.OMDbMapper do
  @moduledoc """
  Traduit une fiche OMDb en notes externes.

  OMDb renvoie tout en chaines de caracteres, avec des formats differents par
  source : `"8.5"` pour IMDb, `"79"` pour Metacritic, `"91%"` pour Rotten
  Tomatoes, `"N/A"` partout ou la note manque, et des separateurs de milliers
  dans le nombre de votes.
  """

  @doc """
  Notes d'une fiche OMDb, prêtes a etre inserees pour `work_id`.
  """
  def rating_attrs(payload, work_id) when is_map(payload) do
    now = DateTime.utc_now(:second)

    [
      imdb(payload),
      metacritic(payload),
      rotten_tomatoes(payload)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Map.merge(&1, %{work_id: work_id, fetched_at: now}))
  end

  defp imdb(payload) do
    case decimal(payload["imdbRating"]) do
      nil ->
        nil

      score ->
        %{
          source: :imdb,
          score: score,
          scale: 10,
          votes_count: integer(payload["imdbVotes"]),
          url: imdb_url(payload["imdbID"])
        }
    end
  end

  defp metacritic(payload) do
    case decimal(payload["Metascore"]) do
      nil -> nil
      score -> %{source: :metacritic, score: score, scale: 100}
    end
  end

  # Rotten Tomatoes n'a pas de champ dedie : il faut le chercher dans la liste
  # `Ratings`, ou il arrive sous forme de pourcentage.
  defp rotten_tomatoes(payload) do
    payload
    |> Map.get("Ratings", [])
    |> List.wrap()
    |> Enum.find(&(is_map(&1) and &1["Source"] == "Rotten Tomatoes"))
    |> case do
      %{"Value" => value} ->
        percentage(value)

      _absent ->
        nil
    end
  end

  defp percentage(value) do
    case value |> String.trim_trailing("%") |> decimal() do
      nil -> nil
      score -> %{source: :rotten_tomatoes, score: score, scale: 100}
    end
  end

  # OMDb ecrit "N/A" la ou la note manque.
  defp decimal("N/A"), do: nil
  defp decimal(nil), do: nil

  defp decimal(value) when is_binary(value) do
    case value |> String.trim() |> Decimal.parse() do
      {decimal, ""} -> decimal
      _other -> nil
    end
  end

  defp decimal(_value), do: nil

  # "1,234,567" : les separateurs de milliers feraient echouer un parse direct.
  defp integer("N/A"), do: nil
  defp integer(nil), do: nil

  defp integer(value) when is_binary(value) do
    case value |> String.replace(",", "") |> Integer.parse() do
      {integer, _rest} -> integer
      :error -> nil
    end
  end

  defp integer(_value), do: nil

  defp imdb_url(nil), do: nil
  defp imdb_url(imdb_id), do: "https://www.imdb.com/title/#{imdb_id}/"
end
