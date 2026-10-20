defmodule Smovie.Catalog.Sync.Mapper do
  @moduledoc """
  Traduit une charge utile TMDB en attributs de `Smovie.Catalog.Work`.

  Module sans effet de bord : il ne touche ni a la base ni au reseau, ce qui
  le rend testable sur des charges utiles figees. C'est la que vivent les
  pieges du format TMDB — chaines vides pour les dates absentes, zeros pour
  les durees inconnues, identifiants externes imbriques.
  """

  alias Smovie.Catalog.WorkKind

  @doc """
  Attributs d'un film.
  """
  def movie_attrs(payload) when is_map(payload) do
    payload
    |> common_attrs()
    |> Map.merge(%{
      kind: :movie,
      title: title(payload, "title"),
      original_title: payload["original_title"],
      release_date: date(payload["release_date"]),
      runtime: positive(payload["runtime"]),
      imdb_id: imdb_id(payload)
    })
  end

  @doc """
  Attributs d'une serie.
  """
  def tv_show_attrs(payload) when is_map(payload) do
    payload
    |> common_attrs()
    |> Map.merge(%{
      kind: :tv_show,
      title: title(payload, "name"),
      original_title: payload["original_name"],
      release_date: date(payload["first_air_date"]),
      # TMDB donne la duree d'episode en liste : plusieurs formats coexistent
      # pour une meme serie, on retient le plus court, qui est le format usuel.
      runtime:
        payload["episode_run_time"] |> List.wrap() |> Enum.min(fn -> nil end) |> positive(),
      season_count: positive(payload["number_of_seasons"]),
      episode_count: positive(payload["number_of_episodes"]),
      imdb_id: imdb_id(payload)
    })
  end

  @doc """
  Attributs d'une saison, rattachee a `parent_id`.
  """
  def season_attrs(payload, parent_id) when is_map(payload) do
    payload
    |> common_attrs()
    |> Map.merge(%{
      kind: :season,
      parent_id: parent_id,
      title: title(payload, "name"),
      season_number: payload["season_number"],
      release_date: date(payload["air_date"]),
      episode_count: payload["episodes"] |> List.wrap() |> length() |> positive()
    })
  end

  @doc """
  Attributs d'un episode, rattache a `parent_id`.
  """
  def episode_attrs(payload, parent_id) when is_map(payload) do
    payload
    |> common_attrs()
    |> Map.merge(%{
      kind: :episode,
      parent_id: parent_id,
      title: title(payload, "name"),
      season_number: payload["season_number"],
      episode_number: payload["episode_number"],
      release_date: date(payload["air_date"]),
      runtime: positive(payload["runtime"])
    })
  end

  @doc """
  Episodes d'une charge utile de saison.
  """
  def episodes_of(payload, parent_id) when is_map(payload) do
    payload
    |> Map.get("episodes", [])
    |> List.wrap()
    |> Enum.map(&episode_attrs(&1, parent_id))
  end

  @doc """
  Nature d'un resultat de `search/multi`.

  TMDB melange films, series et personnes dans la meme liste : `media_type`
  est le seul moyen de les distinguer.
  """
  def kind_of(%{"media_type" => "movie"}), do: {:ok, :movie}
  def kind_of(%{"media_type" => "tv"}), do: {:ok, :tv_show}
  def kind_of(%{"media_type" => "person"}), do: {:ok, :person}
  def kind_of(_result), do: :error

  @doc """
  Attributs d'un resultat de recherche, selon sa nature.
  """
  def search_result_attrs(result) do
    case kind_of(result) do
      {:ok, :movie} -> {:ok, movie_attrs(result)}
      {:ok, :tv_show} -> {:ok, tv_show_attrs(result)}
      _other -> :error
    end
  end

  @doc """
  Chemin TMDB d'une nature, pour construire une URL d'API.
  """
  def tmdb_path_segment(:movie), do: "movie"
  def tmdb_path_segment(:tv_show), do: "tv"

  defp common_attrs(payload) do
    %{
      tmdb_id: payload["id"],
      overview: presence(payload["overview"]),
      tagline: presence(payload["tagline"]),
      poster_path: presence(payload["poster_path"]),
      backdrop_path: presence(payload["backdrop_path"]),
      original_language: presence(payload["original_language"]),
      status: presence(payload["status"]),
      adult: payload["adult"] == true,
      tmdb_popularity: decimal(payload["popularity"]),
      tmdb_vote_average: decimal(payload["vote_average"]),
      tmdb_vote_count: payload["vote_count"],
      synced_at: DateTime.utc_now(:second)
    }
  end

  # Un titre absent produirait un changeset invalide : on retombe sur le titre
  # original, puis sur un libelle, plutot que de perdre l'oeuvre.
  defp title(payload, key) do
    presence(payload[key]) || presence(payload["original_#{key}"]) || "Sans titre"
  end

  # TMDB renvoie "" et non null pour une date absente.
  defp date(value) do
    case presence(value) do
      nil ->
        nil

      binary ->
        case Date.from_iso8601(binary) do
          {:ok, date} -> date
          {:error, _reason} -> nil
        end
    end
  end

  # TMDB renvoie 0 pour une duree ou un decompte inconnu : 0 minute serait faux,
  # nil dit la verite.
  defp positive(value) when is_integer(value) and value > 0, do: value
  defp positive(_value), do: nil

  defp decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp decimal(value) when is_integer(value), do: Decimal.new(value)
  defp decimal(_value), do: nil

  defp presence(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp presence(_value), do: nil

  # `external_ids` arrive via append_to_response ; sur un film il existe aussi
  # a la racine.
  defp imdb_id(%{"external_ids" => %{"imdb_id" => id}}) when is_binary(id), do: presence(id)
  defp imdb_id(%{"imdb_id" => id}) when is_binary(id), do: presence(id)
  defp imdb_id(_payload), do: nil

  @doc """
  Natures qu'un resultat de recherche peut prendre.
  """
  def searchable_kinds, do: WorkKind.roots()
end
