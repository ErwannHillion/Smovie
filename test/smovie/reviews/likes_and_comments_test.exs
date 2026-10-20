defmodule Smovie.Reviews.LikesAndCommentsTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.ReviewsFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Repo
  alias Smovie.Reviews
  alias Smovie.Reviews.ReviewComment

  setup do
    auteur = user_fixture()
    lecteur = user_fixture()
    movie = movie_fixture()

    %{
      auteur: auteur,
      lecteur: lecteur,
      scope: Scope.for_user(lecteur),
      review: review_fixture(auteur, movie)
    }
  end

  describe "likes" do
    test "basculent", %{scope: scope, review: review} do
      assert {:ok, :liked} = Reviews.toggle_like(scope, review)
      assert Reviews.liked?(scope, review)

      assert {:ok, :unliked} = Reviews.toggle_like(scope, review)
      refute Reviews.liked?(scope, review)
    end

    test "mettent a jour le compteur dans la meme transaction", %{scope: scope, review: review} do
      # C'est le chiffre qui classe les reviews populaires : desynchronise, il
      # fausse tout le classement.
      Reviews.toggle_like(scope, review)

      assert Repo.reload!(review).likes_count == 1

      Reviews.toggle_like(scope, review)

      assert Repo.reload!(review).likes_count == 0
    end

    test "un membre ne like qu'une fois", %{scope: scope, review: review} do
      Reviews.toggle_like(scope, review)
      Reviews.toggle_like(scope, review)
      Reviews.toggle_like(scope, review)

      assert Repo.reload!(review).likes_count == 1
    end

    test "liked?/2 est faux pour un visiteur", %{review: review} do
      refute Reviews.liked?(nil, review)
    end

    test "liked_review_ids/2 charge toute une page en une requete", %{
      scope: scope,
      review: review
    } do
      Reviews.toggle_like(scope, review)

      assert Reviews.liked_review_ids(scope, [review]) == MapSet.new([review.id])
      assert Reviews.liked_review_ids(nil, [review]) == MapSet.new()
    end
  end

  describe "commentaires" do
    test "se publient", %{scope: scope, review: review} do
      assert {:ok, comment} = Reviews.comment(scope, review, %{"body" => "Entierement d'accord."})

      assert comment.body == "Entierement d'accord."
      assert Repo.reload!(review).comments_count == 1
    end

    test "refusent un corps vide", %{scope: scope, review: review} do
      assert {:error, changeset} = Reviews.comment(scope, review, %{"body" => "   "})
      assert errors_on(changeset)[:body]
    end

    test "acceptent une reponse a un commentaire racine", %{scope: scope, review: review} do
      {:ok, racine} = Reviews.comment(scope, review, %{"body" => "Un avis."})

      assert {:ok, reponse} =
               Reviews.comment(scope, review, %{
                 "body" => "Une reponse.",
                 "parent_id" => racine.id
               })

      assert reponse.parent_id == racine.id
    end

    test "refusent une reponse rattachee a un fil etranger", %{
      scope: scope,
      review: review,
      auteur: auteur,
      lecteur: lecteur
    } do
      # Sans cette verification, un identifiant forge rattacherait une reponse
      # au fil d'une autre review.
      autre_review = review_fixture(auteur, movie_fixture(%{title: "Autre"}))

      {:ok, ailleurs} =
        Reviews.comment(Scope.for_user(lecteur), autre_review, %{"body" => "La-bas"})

      assert Reviews.comment(scope, review, %{"body" => "Ici", "parent_id" => ailleurs.id}) ==
               {:error, :invalid_parent}
    end

    test "refusent une reponse a une reponse", %{scope: scope, review: review} do
      # Un seul niveau : au-dela, un fil se lit mal sur un telephone.
      {:ok, racine} = Reviews.comment(scope, review, %{"body" => "Racine"})

      {:ok, reponse} =
        Reviews.comment(scope, review, %{"body" => "Reponse", "parent_id" => racine.id})

      assert Reviews.comment(scope, review, %{"body" => "Trop loin", "parent_id" => reponse.id}) ==
               {:error, :invalid_parent}
    end

    test "refusent un commentaire sur une review invisible", %{auteur: auteur, lecteur: lecteur} do
      privee =
        review_fixture(auteur, movie_fixture(%{title: "Privee"}), %{"visibility" => "private"})

      assert Reviews.comment(Scope.for_user(lecteur), privee, %{"body" => "Coucou"}) ==
               {:error, :unauthorized}
    end

    test "list_comments/1 imbrique les reponses", %{scope: scope, review: review} do
      {:ok, racine} = Reviews.comment(scope, review, %{"body" => "Racine"})
      Reviews.comment(scope, review, %{"body" => "Reponse", "parent_id" => racine.id})

      assert [comment] = Reviews.list_comments(review)
      assert length(comment.replies) == 1
    end
  end

  describe "suppression d'un commentaire" do
    setup %{scope: scope, review: review} do
      {:ok, comment} = Reviews.comment(scope, review, %{"body" => "A supprimer"})
      %{comment: comment}
    end

    test "son auteur le peut", %{scope: scope, comment: comment, review: review} do
      assert {:ok, _} = Reviews.delete_comment(scope, comment)
      assert Repo.reload!(review).comments_count == 0
    end

    test "l'auteur de la review le peut aussi", %{auteur: auteur, comment: comment} do
      # Une review est l'espace de son auteur : il doit pouvoir y faire le
      # menage.
      assert {:ok, _} = Reviews.delete_comment(Scope.for_user(auteur), comment)
    end

    test "un tiers ne le peut pas", %{comment: comment} do
      tiers = Scope.for_user(user_fixture())

      assert Reviews.delete_comment(tiers, comment) == {:error, :unauthorized}
      assert Repo.get(ReviewComment, comment.id)
    end
  end
end
