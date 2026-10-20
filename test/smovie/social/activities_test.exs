defmodule Smovie.Social.ActivitiesTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.ReviewsFixtures

  alias Smovie.Accounts
  alias Smovie.Accounts.Scope
  alias Smovie.Library
  alias Smovie.Repo
  alias Smovie.Social
  alias Smovie.Social.Activity

  setup do
    auteur = user_fixture()
    abonne = user_fixture()
    Social.follow(Scope.for_user(abonne), auteur)

    %{
      auteur: auteur,
      auteur_scope: Scope.for_user(auteur),
      abonne: abonne,
      abonne_scope: Scope.for_user(abonne),
      movie: movie_fixture()
    }
  end

  describe "enregistrement" do
    test "noter produit une activite", %{auteur_scope: scope, movie: movie, abonne_scope: abonne} do
      Library.rate_work(scope, movie, 9)

      assert [%{kind: :rated, rating_value: 9}] = Social.list_feed(abonne)
    end

    test "marquer vu produit une activite", %{
      auteur_scope: scope,
      movie: movie,
      abonne_scope: abonne
    } do
      Library.mark_watched(scope, movie)

      assert [%{kind: :watched}] = Social.list_feed(abonne)
    end

    test "publier une review produit une activite", %{
      auteur: auteur,
      movie: movie,
      abonne_scope: abonne
    } do
      review_fixture(auteur, movie)

      kinds = abonne |> Social.list_feed() |> Enum.map(& &1.kind)

      assert :reviewed in kinds
    end

    test "suivre quelqu'un produit une activite", %{abonne_scope: scope} do
      # Le setup a deja produit un abonnement : on en attend donc deux.
      troisieme = user_fixture()
      Social.follow(scope, troisieme)

      activites = Social.list_user_activity(scope.user)

      assert length(activites) == 2
      assert Enum.all?(activites, &(&1.kind == :followed))
    end

    test "une activite sans sujet est refusee", %{auteur_scope: scope} do
      # Elle ne s'afficherait pas : autant la refuser a l'ecriture plutot que
      # de la filtrer a chaque lecture.
      avant = Repo.aggregate(Activity, :count)

      assert Social.record(scope, :rated, %{}) == :ignored
      assert Repo.aggregate(Activity, :count) == avant
    end

    test "une activite perdue ne fait pas echouer l'action", %{auteur_scope: scope, movie: movie} do
      # Une activite est un effet de bord : on ne refuse pas une note parce
      # que le fil n'a pas pu l'enregistrer.
      assert {:ok, _rating} = Library.rate_work(scope, movie, 8)
    end
  end

  describe "list_feed/2" do
    test "ne montre que les comptes suivis", %{
      auteur_scope: scope,
      movie: movie,
      abonne_scope: abonne
    } do
      inconnu = user_fixture()
      Library.rate_work(Scope.for_user(inconnu), movie, 10)
      Library.rate_work(scope, movie, 8)

      assert [activite] = Social.list_feed(abonne)
      assert activite.user_id == scope.user.id
    end

    test "est vide sans abonnement", %{movie: movie} do
      solitaire = Scope.for_user(user_fixture())
      Library.rate_work(solitaire, movie, 8)

      assert Social.list_feed(solitaire) == []
    end

    test "est vide pour un visiteur" do
      assert Social.list_feed(nil) == []
    end

    test "masque l'activite d'un profil prive", %{
      auteur: auteur,
      auteur_scope: scope,
      movie: movie,
      abonne_scope: abonne
    } do
      # Une activite dont l'auteur a ferme son profil n'a pas a circuler.
      Library.rate_work(scope, movie, 9)
      Accounts.update_user_visibility(scope, auteur, %{"profile_visibility" => "private"})

      assert Social.list_feed(abonne) == []
    end

    test "classe du plus recent au plus ancien", %{
      auteur_scope: scope,
      movie: movie,
      abonne_scope: abonne
    } do
      autre = movie_fixture(%{title: "Second"})
      Library.rate_work(scope, movie, 8)
      Library.rate_work(scope, autre, 9)

      assert [premiere | _] = Social.list_feed(abonne)
      assert premiere.work_id == autre.id
    end
  end

  describe "purge_activities/1" do
    test "retire les entrees anciennes", %{auteur_scope: scope, movie: movie} do
      Library.rate_work(scope, movie, 8)

      Repo.update_all(Activity,
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -120, :day)]
      )

      assert {:ok, count} = Social.purge_activities()
      assert count > 0
      assert Repo.aggregate(Activity, :count) == 0
    end

    test "conserve les entrees recentes", %{auteur_scope: scope, movie: movie} do
      Library.rate_work(scope, movie, 8)
      avant = Repo.aggregate(Activity, :count)

      assert {:ok, 0} = Social.purge_activities()
      assert Repo.aggregate(Activity, :count) == avant
    end
  end
end
