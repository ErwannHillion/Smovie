defmodule SmovieWeb.WorkLive.SeasonTest do
  use SmovieWeb.ConnCase, async: true
  use Oban.Testing, repo: Smovie.Repo

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Library
  alias Smovie.Workers.SyncSeasonsWorker

  setup do
    show = tv_show_fixture()
    season = season_fixture(show, %{season_number: 1, title: "Saison 1"})

    episodes =
      for n <- 1..3,
          do: episode_fixture(season, %{episode_number: n, title: "Episode #{n}", runtime: 48})

    %{show: show, season: season, episodes: episodes, user: user_fixture()}
  end

  describe "fiche serie" do
    test "liste les saisons avec leur progression", %{conn: conn, show: show, user: user} do
      episode =
        show |> Smovie.Catalog.list_seasons() |> hd() |> Smovie.Catalog.list_episodes() |> hd()

      Library.mark_watched(Scope.for_user(user), episode)

      {:ok, _lv, html} = conn |> log_in_user(user) |> live(~p"/serie/#{show.slug}")

      assert html =~ "Saison 1"
      assert html =~ "3 episodes"
      assert html =~ "1 vus"
    end

    test "met les saisons en file quand elles manquent", %{conn: conn} do
      # La page s'affiche avec ce qu'on a ; importer dix saisons dans le cycle
      # de requete bloquerait la page dix fois.
      vide = tv_show_fixture(%{title: "Sans saisons", season_count: 3})

      {:ok, _lv, _html} = live(conn, ~p"/serie/#{vide.slug}")

      assert_enqueued(worker: SyncSeasonsWorker, args: %{show_id: vide.id})
    end
  end

  describe "page saison" do
    test "liste les episodes dans l'ordre", %{conn: conn, show: show} do
      {:ok, _lv, html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      assert html =~ "S01E01"
      assert html =~ "S01E03"
      assert html =~ "Episode 2"
    end

    test "affiche la progression", %{conn: conn, show: show, user: user, episodes: episodes} do
      Library.mark_watched(Scope.for_user(user), hd(episodes))

      {:ok, _lv, html} = conn |> log_in_user(user) |> live(~p"/serie/#{show.slug}/saison/1")

      assert html =~ "3 episodes"
      assert html =~ "1 vus"
    end

    test "une saison inexistante sort en 404", %{conn: conn, show: show} do
      assert_error_sent 404, fn -> live(conn, ~p"/serie/#{show.slug}/saison/9") end
    end

    test "un numero illisible sort en 404, pas en 500", %{conn: conn, show: show} do
      # Le numero vient de l'URL, donc de l'exterieur.
      assert_error_sent 404, fn -> live(conn, "/serie/#{show.slug}/saison/abc") end
    end

    test "une serie inconnue sort en 404", %{conn: conn} do
      assert_error_sent 404, fn -> live(conn, ~p"/serie/inconnue/saison/1") end
    end
  end
end
