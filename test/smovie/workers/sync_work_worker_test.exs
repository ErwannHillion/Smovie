defmodule Smovie.Workers.SyncWorkWorkerTest do
  use Smovie.DataCase, async: true
  use Oban.Testing, repo: Smovie.Repo

  import Mox
  import Smovie.TMDBPayloads

  alias Smovie.External.TMDBMock
  alias Smovie.Workers.SyncWorkWorker

  setup :verify_on_exit!

  test "synchronise un film" do
    expect(TMDBMock, :get_movie, fn 693_134 -> {:ok, movie()} end)

    assert :ok = perform_job(SyncWorkWorker, %{"kind" => "movie", "tmdb_id" => 693_134})
  end

  test "annule plutot que de reessayer sur une oeuvre retiree de TMDB" do
    # Une oeuvre supprimee ne reviendra pas : la reessayer trois fois ne sert
    # qu'a consommer du quota.
    expect(TMDBMock, :get_movie, fn _ -> {:error, :not_found} end)

    assert {:cancel, :not_found} =
             perform_job(SyncWorkWorker, %{"kind" => "movie", "tmdb_id" => 1})
  end

  test "annule quand la cle API manque" do
    expect(TMDBMock, :get_tv_show, fn _ -> {:error, :missing_api_key} end)

    assert {:cancel, :missing_api_key} =
             perform_job(SyncWorkWorker, %{"kind" => "tv_show", "tmdb_id" => 1})
  end

  test "reessaie sur une erreur transitoire" do
    expect(TMDBMock, :get_movie, fn _ -> {:error, :rate_limited} end)

    assert {:error, :rate_limited} =
             perform_job(SyncWorkWorker, %{"kind" => "movie", "tmdb_id" => 1})
  end

  test "enqueue/2 met le job en file" do
    assert {:ok, _job} = SyncWorkWorker.enqueue(:movie, 693_134)

    assert_enqueued(worker: SyncWorkWorker, args: %{kind: "movie", tmdb_id: 693_134})
  end
end
