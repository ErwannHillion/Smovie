defmodule Smovie.Catalog.BootstrapTest do
  use Smovie.DataCase, async: false
  use Oban.Testing, repo: Smovie.Repo

  import Smovie.CatalogFixtures

  alias Smovie.Catalog.Bootstrap
  alias Smovie.Workers.SyncTrendingCatalogWorker

  setup do
    original = Application.get_env(:smovie, :catalog)
    on_exit(fn -> Application.put_env(:smovie, :catalog, original) end)
    %{original: original}
  end

  defp with_bootstrap(original, overrides, fun) do
    Application.put_env(:smovie, :catalog, Keyword.merge(original || [], overrides))
    fun.()
  end

  test "met la synchronisation en file sur un catalogue vide", %{original: original} do
    # Sans cela, une installation neuve reste sur une page d'accueil vide
    # jusqu'a la prochaine synchronisation planifiee.
    with_bootstrap(original, [bootstrap_on_boot: true], fn ->
      assert :ok = Bootstrap.run()
      assert_enqueued(worker: SyncTrendingCatalogWorker)
    end)
  end

  test "ne fait rien sur un catalogue deja fourni", %{original: original} do
    with_bootstrap(original, [bootstrap_on_boot: true, bootstrap_threshold: 2], fn ->
      for n <- 1..3, do: movie_fixture(%{title: "Film #{n}"})

      assert :ok = Bootstrap.run()
      refute_enqueued(worker: SyncTrendingCatalogWorker)
    end)
  end

  test "est idempotent : un redemarrage ne reempile pas", %{original: original} do
    with_bootstrap(original, [bootstrap_on_boot: true, bootstrap_threshold: 2], fn ->
      Bootstrap.run()
      for n <- 1..3, do: movie_fixture(%{title: "Film #{n}"})
      Bootstrap.run()

      assert [_un_seul] = all_enqueued(worker: SyncTrendingCatalogWorker)
    end)
  end

  test "ne compte ni les saisons ni les episodes", %{original: original} do
    # Une serie importee seule ne remplit pas une page d'accueil : compter ses
    # episodes donnerait l'illusion d'un catalogue fourni.
    with_bootstrap(original, [bootstrap_on_boot: true, bootstrap_threshold: 3], fn ->
      show = tv_show_fixture()
      season = season_fixture(show)
      for n <- 1..5, do: episode_fixture(season, %{episode_number: n, title: "E#{n}"})

      assert :ok = Bootstrap.run()
      assert_enqueued(worker: SyncTrendingCatalogWorker)
    end)
  end

  test "reste inactif quand l'amorcage est coupe", %{original: original} do
    with_bootstrap(original, [bootstrap_on_boot: false], fn ->
      assert :ok = Bootstrap.run()
      refute_enqueued(worker: SyncTrendingCatalogWorker)
    end)
  end
end
