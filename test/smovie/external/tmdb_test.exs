defmodule Smovie.External.TMDBTest do
  use ExUnit.Case, async: true

  import Mox
  import Smovie.TMDBPayloads

  alias Smovie.External.TMDB
  alias Smovie.External.TMDBMock

  setup :verify_on_exit!

  describe "facade" do
    test "delegue a l'implementation configuree" do
      expect(TMDBMock, :get_movie, fn 693_134 -> {:ok, movie()} end)

      assert {:ok, %{"id" => 693_134}} = TMDB.get_movie(693_134)
    end

    test "transmet la fenetre par defaut des tendances" do
      expect(TMDBMock, :trending, fn :movie, :week -> {:ok, search_multi([])} end)

      assert {:ok, _} = TMDB.trending(:movie)
    end

    test "remonte les erreurs telles quelles" do
      expect(TMDBMock, :get_movie, fn _ -> {:error, :not_found} end)

      assert TMDB.get_movie(1) == {:error, :not_found}
    end
  end

  describe "contrat du comportement" do
    test "la doublure implemente toutes les fonctions appelees par la facade" do
      # Si une fonction manque au comportement, Mox refuse de la programmer :
      # ce test verifie que facade et comportement ne divergent pas.
      expect(TMDBMock, :search_multi, fn "dune", [] -> {:ok, search_multi([])} end)
      expect(TMDBMock, :get_tv_show, fn _ -> {:ok, tv_show()} end)
      expect(TMDBMock, :get_season, fn _, _ -> {:ok, season()} end)
      expect(TMDBMock, :now_playing, fn [] -> {:ok, search_multi([])} end)
      expect(TMDBMock, :on_the_air, fn [] -> {:ok, search_multi([])} end)
      expect(TMDBMock, :genres, fn :movie -> {:ok, %{"genres" => []}} end)

      assert {:ok, _} = TMDB.search_multi("dune")
      assert {:ok, _} = TMDB.get_tv_show(1)
      assert {:ok, _} = TMDB.get_season(1, 1)
      assert {:ok, _} = TMDB.now_playing()
      assert {:ok, _} = TMDB.on_the_air()
      assert {:ok, _} = TMDB.genres(:movie)
    end
  end
end
