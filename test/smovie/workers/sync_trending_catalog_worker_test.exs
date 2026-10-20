defmodule Smovie.Workers.SyncTrendingCatalogWorkerTest do
  use Smovie.DataCase, async: true
  use Oban.Testing, repo: Smovie.Repo

  import Mox
  import Smovie.TMDBPayloads

  alias Smovie.External.TMDBMock
  alias Smovie.Workers.SyncTrendingCatalogWorker, as: Worker

  setup :verify_on_exit!

  defp stub_sources(results) do
    stub(TMDBMock, :now_playing, fn _opts -> {:ok, search_multi(results)} end)
    stub(TMDBMock, :on_the_air, fn _opts -> {:ok, search_multi([])} end)
    stub(TMDBMock, :trending, fn _type, _window -> {:ok, search_multi([])} end)
  end

  test "importe les oeuvres des quatre sources" do
    stub_sources([search_movie()])

    assert :ok = perform_job(Worker, %{})
    assert Smovie.Repo.aggregate(Smovie.Catalog.Work, :count) == 1
  end

  test "une source en panne n'emporte pas les autres" do
    stub(TMDBMock, :now_playing, fn _opts -> {:error, :rate_limited} end)
    stub(TMDBMock, :on_the_air, fn _opts -> {:ok, search_multi([search_tv()])} end)
    stub(TMDBMock, :trending, fn _type, _window -> {:ok, search_multi([])} end)

    assert :ok = perform_job(Worker, %{})
    assert Smovie.Repo.aggregate(Smovie.Catalog.Work, :count) == 1
  end

  test "echoue quand les quatre sources ne rendent rien" do
    # Zero oeuvre sur quatre sources, c'est une panne et non un creux.
    stub(TMDBMock, :now_playing, fn _opts -> {:error, :request_failed} end)
    stub(TMDBMock, :on_the_air, fn _opts -> {:error, :request_failed} end)
    stub(TMDBMock, :trending, fn _type, _window -> {:error, :request_failed} end)

    assert {:error, :no_work_imported} = perform_job(Worker, %{})
  end
end
