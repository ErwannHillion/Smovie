defmodule Smovie.External.OMDb do
  @moduledoc """
  Facade du client OMDb, source des notes presse.

  OMDb est optionnel : son palier gratuit plafonne a mille requetes par jour,
  et l'application doit rester utilisable sans lui. Coupe, elle affiche la note
  TMDB seule, sans erreur visible.
  """

  alias Smovie.Config

  @doc """
  Fiche OMDb d'une oeuvre, par son identifiant IMDb.
  """
  @callback get_by_imdb_id(imdb_id :: String.t()) :: {:ok, map()} | {:error, term()}

  def get_by_imdb_id(imdb_id), do: Config.omdb_impl().get_by_imdb_id(imdb_id)
end
