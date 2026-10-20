defmodule SmovieWeb.WorkLive.EpisodeRatingTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Library

  setup do
    user = user_fixture()
    show = tv_show_fixture()
    season = season_fixture(show, %{season_number: 1, title: "Saison 1"})
    episodes = for n <- 1..3, do: episode_fixture(season, %{episode_number: n, title: "E#{n}"})

    %{user: user, scope: Scope.for_user(user), show: show, season: season, episodes: episodes}
  end

  describe "notation episode par episode" do
    setup %{conn: conn, user: user}, do: %{conn: log_in_user(conn, user)}

    test "chaque episode porte dix crans de notation", %{conn: conn, show: show} do
      {:ok, _lv, html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      # Trois episodes, dix crans chacun.
      assert html |> String.split(~s(phx-click="rate_episode")) |> length() == 31
    end

    test "noter un episode l'enregistre", %{
      conn: conn,
      show: show,
      scope: scope,
      episodes: episodes
    } do
      {:ok, lv, _html} = live(conn, ~p"/serie/#{show.slug}/saison/1")
      [premier | _] = episodes

      lv
      |> element(
        ~s(button[phx-click="rate_episode"][phx-value-work-id="#{premier.id}"][phx-value-value="9"])
      )
      |> render_click()

      assert Library.get_rating(scope, premier).value == 9
    end

    test "noter un episode ne note pas les autres", %{
      conn: conn,
      show: show,
      scope: scope,
      episodes: [a, b | _]
    } do
      {:ok, lv, _html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      lv
      |> element(
        ~s(button[phx-click="rate_episode"][phx-value-work-id="#{a.id}"][phx-value-value="8"])
      )
      |> render_click()

      assert Library.get_rating(scope, a).value == 8
      assert Library.get_rating(scope, b) == nil
    end

    test "noter un episode ne note pas la serie", %{
      conn: conn,
      show: show,
      scope: scope,
      episodes: [a | _]
    } do
      {:ok, lv, _html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      lv
      |> element(
        ~s(button[phx-click="rate_episode"][phx-value-work-id="#{a.id}"][phx-value-value="8"])
      )
      |> render_click()

      assert Library.get_rating(scope, show) == nil
    end

    test "reposer la meme note la retire", %{
      conn: conn,
      show: show,
      scope: scope,
      episodes: [a | _]
    } do
      {:ok, lv, _html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      bouton =
        ~s(button[phx-click="rate_episode"][phx-value-work-id="#{a.id}"][phx-value-value="8"])

      lv |> element(bouton) |> render_click()
      lv |> element(bouton) |> render_click()

      assert Library.get_rating(scope, a) == nil
    end

    test "chaque cran fait au moins 44 px de haut", %{conn: conn, show: show} do
      # Une liste d'episodes aligne vingt selecteurs : des cibles minuscules y
      # seraient encore moins touchables que sur une fiche.
      {:ok, _lv, html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      assert html =~ "min-h-11"
    end
  end

  describe "marquage vu" do
    setup %{conn: conn, user: user}, do: %{conn: log_in_user(conn, user)}

    test "bascule un episode", %{conn: conn, show: show, scope: scope, episodes: [a | _]} do
      {:ok, lv, _html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      lv
      |> element(~s(button[phx-click="toggle_watched"][phx-value-work-id="#{a.id}"]))
      |> render_click()

      assert Library.watched?(scope, a)
    end

    test "la progression suit", %{conn: conn, show: show, episodes: [a | _]} do
      {:ok, lv, _html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      html =
        lv
        |> element(~s(button[phx-click="toggle_watched"][phx-value-work-id="#{a.id}"]))
        |> render_click()

      assert html =~ "1 vus"
    end

    test "marquer toute la saison couvre tous les episodes", %{
      conn: conn,
      show: show,
      scope: scope,
      season: season
    } do
      {:ok, lv, _html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      lv |> element(~s(button[phx-click="mark_season_watched"])) |> render_click()

      assert Library.season_progress(scope, season) == %{watched: 3, total: 3}
    end

    test "le bouton disparait quand toute la saison est vue", %{conn: conn, show: show} do
      {:ok, lv, _html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      html = lv |> element(~s(button[phx-click="mark_season_watched"])) |> render_click()

      refute html =~ "Marquer toute la saison"
    end
  end

  describe "visiteur non connecte" do
    test "noter un episode renvoie vers la connexion", %{
      conn: conn,
      show: show,
      episodes: [a | _]
    } do
      {:ok, lv, _html} = live(conn, ~p"/serie/#{show.slug}/saison/1")

      assert {:error, {:live_redirect, %{to: "/users/log-in"}}} =
               lv
               |> element(
                 ~s(button[phx-click="rate_episode"][phx-value-work-id="#{a.id}"][phx-value-value="8"])
               )
               |> render_click()
    end
  end
end
