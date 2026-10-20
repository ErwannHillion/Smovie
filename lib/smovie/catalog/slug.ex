defmodule Smovie.Catalog.Slug do
  @moduledoc """
  Fabrique les adresses lisibles des oeuvres.

  Le slug est fige a la creation et preserve par les resynchronisations TMDB :
  une URL partagee dans une conversation ou une review ne doit pas cesser de
  fonctionner parce qu'un titre a ete corrige en amont.
  """

  @max_length 160

  @doc """
  Slug d'un film ou d'une serie : titre, puis annee pour desambiguiser.

      iex> Smovie.Catalog.Slug.build("Dune, deuxième partie", ~D[2024-02-28])
      "dune-deuxieme-partie-2024"
  """
  def build(title, %Date{year: year}), do: join([slugify(title), Integer.to_string(year)])
  def build(title, nil), do: slugify(title)

  @doc """
  Slug d'une saison : celui de la serie, suffixe du numero.
  """
  def build_season(series_slug, number), do: join([series_slug, "saison", to_string(number)])

  @doc """
  Slug d'un episode : celui de la serie, suffixe de SxxEyy.

  Le format `s02e07` plutot que `saison-2-episode-7` : c'est la notation que
  les gens emploient, et elle se trie correctement.
  """
  def build_episode(series_slug, season_number, episode_number) do
    join([series_slug, "s#{pad(season_number)}e#{pad(episode_number)}"])
  end

  @doc """
  Rend un slug unique en le suffixant, `taken?` disant ce qui est deja pris.
  """
  def unique(base, taken?) do
    if taken?.(base) do
      2..999
      |> Stream.map(&join([base, to_string(&1)]))
      |> Enum.find(&(not taken?.(&1)))
    else
      base
    end
  end

  @doc """
  Translitere un titre en segment d'URL.

  Les accents sont depouilles plutot que percent-encodes : une URL lisible se
  recopie a la main et se dicte au telephone.
  """
  def slugify(nil), do: ""

  def slugify(title) do
    title
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> String.slice(0, @max_length)
    |> String.trim("-")
    |> fallback()
  end

  defp fallback(""), do: "oeuvre"
  defp fallback(slug), do: slug

  defp join(parts), do: parts |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join("-")

  defp pad(number), do: number |> to_string() |> String.pad_leading(2, "0")
end
