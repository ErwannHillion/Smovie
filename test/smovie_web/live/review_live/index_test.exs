defmodule SmovieWeb.ReviewLive.IndexTest do
  use SmovieWeb.ConnCase, async: true

  import Ecto.Query

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.ReviewsFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Repo
  alias Smovie.Reviews.Review
  alias Smovie.Social

  setup do
    auteur = user_fixture()
    lecteur = user_fixture()
    movie = movie_fixture()
    %{auteur: auteur, lecteur: lecteur, movie: movie, review: review_fixture(auteur, movie)}
  end

  test "l'onglet populaires liste les reviews", %{conn: conn, movie: movie} do
    {:ok, _lv, html} = live(conn, ~p"/reviews")

    assert html =~ "hors-champ"
    assert html =~ movie.title
  end

  test "une review recente et likee passe devant une ancienne plus likee", %{conn: conn} do
    # Classer par likes seuls figerait la page sur les reviews anciennes.
    ancienne = review_fixture(user_fixture(), movie_fixture(%{title: "Ancienne"}))
    recente = review_fixture(user_fixture(), movie_fixture(%{title: "Recente"}))

    Repo.update_all(from(r in Review, where: r.id == ^ancienne.id),
      set: [likes_count: 40, published_at: DateTime.add(DateTime.utc_now(), -13, :day)]
    )

    Repo.update_all(from(r in Review, where: r.id == ^recente.id), set: [likes_count: 12])

    {:ok, _lv, html} = live(conn, ~p"/reviews")

    assert index_of(html, "Recente") < index_of(html, "Ancienne")
  end

  test "l'onglet recentes classe par date", %{conn: conn} do
    review_fixture(user_fixture(), movie_fixture(%{title: "Plus recente"}))

    {:ok, _lv, html} = live(conn, ~p"/reviews?onglet=recentes")

    assert html =~ "Plus recente"
  end

  test "l'onglet abonnements ne montre que les comptes suivis", %{
    conn: conn,
    auteur: auteur,
    lecteur: lecteur
  } do
    review_fixture(user_fixture(), movie_fixture(%{title: "Inconnu"}))
    Social.follow(Scope.for_user(lecteur), auteur)

    {:ok, _lv, html} = conn |> log_in_user(lecteur) |> live(~p"/reviews?onglet=abonnements")

    assert html =~ "hors-champ"
    refute html =~ "Inconnu"
  end

  test "l'onglet abonnements invite le visiteur a se connecter", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/reviews?onglet=abonnements")

    assert html =~ "Connectez-vous"
  end

  test "un onglet inconnu retombe sur populaires", %{conn: conn} do
    # L'onglet vient de l'URL, donc de l'exterieur.
    {:ok, _lv, html} = live(conn, ~p"/reviews?onglet=nimportequoi")

    assert html =~ "hors-champ"
  end

  test "les reviews non publiques n'y figurent pas", %{conn: conn, auteur: auteur} do
    review_fixture(auteur, movie_fixture(%{title: "Secrete"}), %{"visibility" => "private"})

    {:ok, _lv, html} = live(conn, ~p"/reviews?onglet=recentes")

    refute html =~ "Secrete"
  end

  defp index_of(html, needle), do: html |> String.split(needle) |> hd() |> String.length()
end
