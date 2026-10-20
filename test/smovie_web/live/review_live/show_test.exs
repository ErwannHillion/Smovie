defmodule SmovieWeb.ReviewLive.ShowTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.ReviewsFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Reviews

  setup do
    user = user_fixture()
    movie = movie_fixture()
    %{user: user, scope: Scope.for_user(user), movie: movie, review: review_fixture(user, movie)}
  end

  describe "page review" do
    test "affiche la review en entier", %{conn: conn, review: review, movie: movie} do
      {:ok, _lv, html} = live(conn, ~p"/review/#{review.id}")

      assert html =~ "hors-champ"
      assert html =~ movie.title
    end

    test "une review privee se comporte comme absente", %{conn: conn, user: user, movie: movie} do
      # Repondre « existe mais vous n'y avez pas droit » revelerait deja
      # quelque chose.
      review = review_fixture(user, movie, %{"visibility" => "private"})

      assert_error_sent 404, fn -> live(conn, ~p"/review/#{review.id}") end
    end

    test "son auteur y accede", %{conn: conn, user: user, movie: movie} do
      review = review_fixture(user, movie, %{"visibility" => "private"})

      assert {:ok, _lv, _html} = conn |> log_in_user(user) |> live(~p"/review/#{review.id}")
    end

    test "un identifiant inconnu sort en 404", %{conn: conn} do
      assert_error_sent 404, fn -> live(conn, ~p"/review/999999") end
    end

    test "un identifiant illisible sort en 404", %{conn: conn} do
      assert_error_sent 404, fn -> live(conn, "/review/abc") end
    end
  end

  describe "spoilers" do
    setup %{user: user, movie: movie} do
      %{spoiler: review_fixture(user, movie, %{"contains_spoilers" => true})}
    end

    test "sont floutes par defaut", %{conn: conn, spoiler: spoiler} do
      # Floutes et non masques : l'espace reste occupe, donc la page ne saute
      # pas quand on les revele.
      {:ok, _lv, html} = live(conn, ~p"/review/#{spoiler.id}")

      assert html =~ "blur-"
      assert html =~ "Contient des spoilers"
    end

    test "se revelent au clic", %{conn: conn, spoiler: spoiler} do
      {:ok, lv, _html} = live(conn, ~p"/review/#{spoiler.id}")

      html = lv |> element(~s(button[phx-click="reveal"])) |> render_click()

      refute html =~ "blur-"
    end
  end

  describe "redaction depuis la fiche" do
    setup %{conn: conn, user: user}, do: %{conn: log_in_user(conn, user)}

    test "publie une review", %{conn: conn, scope: scope} do
      autre = movie_fixture(%{title: "Perfect Days"})
      {:ok, lv, _html} = live(conn, ~p"/film/#{autre.slug}")

      lv |> element(~s(button[phx-click="edit_review"])) |> render_click()

      html =
        lv
        |> form("#review_form", %{"review" => %{"body" => "Un film sur la lumiere."}})
        |> render_submit()

      assert html =~ "Review publiee."
      assert Reviews.get_user_review(scope, autre).body == "Un film sur la lumiere."
    end

    test "affiche l'erreur sur un corps vide", %{conn: conn} do
      autre = movie_fixture(%{title: "Aftersun"})
      {:ok, lv, _html} = live(conn, ~p"/film/#{autre.slug}")

      lv |> element(~s(button[phx-click="edit_review"])) |> render_click()

      html = lv |> form("#review_form", %{"review" => %{"body" => ""}}) |> render_submit()

      assert html =~ "can&#39;t be blank" or html =~ "blank"
    end

    test "supprime sa review", %{conn: conn, scope: scope, movie: movie} do
      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")

      lv |> element(~s(button[phx-click="delete_review"])) |> render_click()

      assert Reviews.get_user_review(scope, movie) == nil
    end
  end

  describe "reviews populaires sur la fiche" do
    test "sont listees", %{conn: conn, movie: movie} do
      {:ok, _lv, html} = live(conn, ~p"/film/#{movie.slug}")

      assert html =~ "Reviews populaires"
      assert html =~ "hors-champ"
    end
  end

  describe "visiteur" do
    test "est renvoye vers la connexion pour ecrire", %{conn: conn} do
      autre = movie_fixture(%{title: "Zone"})
      {:ok, lv, _html} = live(conn, ~p"/film/#{autre.slug}")

      assert {:error, {:live_redirect, %{to: "/users/log-in"}}} =
               lv |> element(~s(button[phx-click="edit_review"])) |> render_click()
    end
  end

  describe "likes et commentaires" do
    setup %{conn: conn, user: user} do
      lecteur = user_fixture()
      %{conn: log_in_user(conn, lecteur), lecteur: lecteur, auteur: user}
    end

    test "liker met a jour le compteur affiche", %{conn: conn, review: review} do
      {:ok, lv, _html} = live(conn, ~p"/review/#{review.id}")

      html = lv |> element(~s(button[phx-click="toggle_like"])) |> render_click()

      assert html =~ "1 j&#39;aime" or html =~ "1 j'aime"
    end

    test "publier un commentaire l'affiche", %{conn: conn, review: review} do
      {:ok, lv, _html} = live(conn, ~p"/review/#{review.id}")

      html =
        lv
        |> form("#comment_form", %{"comment" => %{"body" => "Entierement d'accord."}})
        |> render_submit()

      assert html =~ "Entierement d&#39;accord." or html =~ "Entierement d'accord."
      assert html =~ "1 commentaire"
    end

    test "repondre a un commentaire", %{conn: conn, review: review} do
      {:ok, lv, _html} = live(conn, ~p"/review/#{review.id}")

      lv |> form("#comment_form", %{"comment" => %{"body" => "Racine"}}) |> render_submit()
      lv |> element(~s(button[phx-click="reply_to"])) |> render_click()

      html =
        lv
        |> form("#comment_form", %{"comment" => %{"body" => "Une reponse"}})
        |> render_submit()

      assert html =~ "Une reponse"
      assert html =~ "2 commentaires"
    end

    test "supprimer son commentaire", %{conn: conn, review: review} do
      {:ok, lv, _html} = live(conn, ~p"/review/#{review.id}")

      lv |> form("#comment_form", %{"comment" => %{"body" => "A effacer"}}) |> render_submit()
      html = lv |> element(~s(button[phx-click="delete_comment"])) |> render_click()

      refute html =~ "A effacer"
    end

    test "un visiteur est renvoye vers la connexion", %{review: review} do
      {:ok, lv, _html} = live(build_conn(), ~p"/review/#{review.id}")

      assert {:error, {:live_redirect, %{to: "/users/log-in"}}} =
               lv |> element(~s(button[phx-click="toggle_like"])) |> render_click()
    end
  end
end
