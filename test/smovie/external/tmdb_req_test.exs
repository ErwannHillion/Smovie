defmodule Smovie.External.TMDB.ReqTest do
  @moduledoc """
  Le client reel, teste sans reseau.

  La configuration applicative etant globale au noeud, ces cas ne peuvent pas
  tourner en parallele.
  """
  use ExUnit.Case, async: false

  alias Smovie.External.TMDB.Req, as: Client

  setup do
    original = Application.get_env(:smovie, :tmdb)
    on_exit(fn -> Application.put_env(:smovie, :tmdb, original) end)
    %{original: original}
  end

  describe "identifiant absent" do
    test "renvoie une erreur au lieu de lever", %{original: original} do
      # Une cle absente est un probleme de deploiement, pas un bug :
      # l'application doit pouvoir degrader plutot que sortir en 500.
      Application.put_env(
        :smovie,
        :tmdb,
        original |> Keyword.put(:api_key, nil) |> Keyword.put(:access_token, nil)
      )

      assert Client.get_movie(1) == {:error, :missing_api_key}
      assert Client.search_multi("dune", []) == {:error, :missing_api_key}
      assert Client.trending(:movie, :week) == {:error, :missing_api_key}
    end

    test "traite une cle vide comme absente", %{original: original} do
      Application.put_env(
        :smovie,
        :tmdb,
        original |> Keyword.put(:api_key, "") |> Keyword.put(:access_token, nil)
      )

      assert Client.get_movie(1) == {:error, :missing_api_key}
    end
  end
end
