defmodule Smovie.Social.NotificationsTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.ReviewsFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Reviews
  alias Smovie.Social

  setup do
    auteur = user_fixture()
    lecteur = user_fixture()
    movie = movie_fixture()

    %{
      auteur: auteur,
      auteur_scope: Scope.for_user(auteur),
      lecteur: lecteur,
      lecteur_scope: Scope.for_user(lecteur),
      review: review_fixture(auteur, movie)
    }
  end

  test "un abonnement notifie la personne suivie", %{auteur_scope: scope, lecteur_scope: autre} do
    Social.follow(autre, scope.user)

    assert [%{kind: :new_follower}] = Social.list_notifications(scope)
    assert Social.unread_count(scope) == 1
  end

  test "un like notifie l'auteur de la review", %{
    auteur_scope: scope,
    lecteur_scope: autre,
    review: review
  } do
    Reviews.toggle_like(autre, review)

    assert [%{kind: :review_liked}] = Social.list_notifications(scope)
  end

  test "retirer un like ne notifie pas", %{
    auteur_scope: scope,
    lecteur_scope: autre,
    review: review
  } do
    Reviews.toggle_like(autre, review)
    Reviews.toggle_like(autre, review)

    assert length(Social.list_notifications(scope)) == 1
  end

  test "un commentaire notifie l'auteur de la review", %{
    auteur_scope: scope,
    lecteur_scope: autre,
    review: review
  } do
    Reviews.comment(autre, review, %{"body" => "Bien vu."})

    assert [%{kind: :review_commented}] = Social.list_notifications(scope)
  end

  test "une reponse notifie l'auteur du commentaire parent", %{
    auteur_scope: auteur,
    lecteur_scope: lecteur,
    review: review
  } do
    {:ok, racine} = Reviews.comment(lecteur, review, %{"body" => "Un avis"})
    Reviews.comment(auteur, review, %{"body" => "Ma reponse", "parent_id" => racine.id})

    assert [%{kind: :comment_replied}] = Social.list_notifications(lecteur)
  end

  test "on ne se notifie jamais soi-meme", %{auteur_scope: scope, review: review} do
    # Liker sa propre review ou se repondre ne doit pas allumer le badge.
    Reviews.toggle_like(scope, review)
    Reviews.comment(scope, review, %{"body" => "Je me reponds"})

    assert Social.list_notifications(scope) == []
  end

  test "mark_all_read/1 eteint le badge", %{
    auteur_scope: scope,
    lecteur_scope: autre,
    review: review
  } do
    Reviews.toggle_like(autre, review)

    assert {:ok, 1} = Social.mark_all_read(scope)
    assert Social.unread_count(scope) == 0
  end

  test "unread_count/1 vaut zero pour un visiteur" do
    assert Social.unread_count(nil) == 0
  end

  test "une notification annonce le changement sur PubSub", %{
    auteur_scope: scope,
    lecteur_scope: autre,
    review: review
  } do
    Phoenix.PubSub.subscribe(Smovie.PubSub, Social.inbox_topic(scope.user.id))

    Reviews.toggle_like(autre, review)

    assert_receive :unread_changed
  end
end
