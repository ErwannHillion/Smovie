defmodule Smovie.ReviewsTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.ReviewsFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Library
  alias Smovie.Repo
  alias Smovie.Reviews
  alias Smovie.Reviews.Review
  alias Smovie.Social

  setup do
    user = user_fixture()
    %{user: user, scope: Scope.for_user(user), movie: movie_fixture()}
  end

  describe "publish/3" do
    test "publie une review", %{scope: scope, movie: movie} do
      assert {:ok, review} = Reviews.publish(scope, movie, %{"body" => long_body()})

      assert review.body == long_body()
      assert review.visibility == :public
      assert review.published_at
    end

    test "une seconde review remplace la premiere", %{scope: scope, movie: movie} do
      # Une review par membre et par oeuvre : c'est ce qui garantit cinq
      # auteurs differents dans les reviews populaires d'une fiche.
      Reviews.publish(scope, movie, %{"body" => "Premiere version"})
      {:ok, review} = Reviews.publish(scope, movie, %{"body" => "Seconde version"})

      assert review.body == "Seconde version"
      assert Repo.aggregate(Review, :count) == 1
    end

    test "recopie la note courante de l'auteur", %{scope: scope, movie: movie, user: user} do
      Library.rate_work(scope, movie, 9)

      {:ok, review} = Reviews.publish(scope, movie, %{"body" => long_body()})

      assert review.rating_value == 9

      # Une note revue plus tard ne doit pas reecrire l'histoire.
      Library.rate_work(Scope.for_user(user), movie, 4)

      assert Repo.reload!(review).rating_value == 9
    end

    test "marque l'oeuvre vue", %{scope: scope, movie: movie} do
      # On n'ecrit pas sur un film qu'on n'a pas vu, et le demander serait un
      # geste de plus pour une information deja donnee.
      Reviews.publish(scope, movie, %{"body" => long_body()})

      assert Library.watched?(scope, movie)
    end

    test "refuse un corps vide", %{scope: scope, movie: movie} do
      assert {:error, changeset} = Reviews.publish(scope, movie, %{"body" => "   "})
      assert errors_on(changeset)[:body]
    end

    test "met a jour le compteur de l'oeuvre", %{scope: scope, movie: movie} do
      Reviews.publish(scope, movie, %{"body" => long_body()})

      assert Repo.reload!(movie).smovie_review_count == 1
    end

    test "une review privee ne compte pas dans le compteur public", %{scope: scope, movie: movie} do
      Reviews.publish(scope, movie, %{"body" => long_body(), "visibility" => "private"})

      assert Repo.reload!(movie).smovie_review_count == 0
    end

    test "une review privee laisse la note dans la moyenne", %{scope: scope, movie: movie} do
      # Une review privee est un texte prive, pas un vote retire.
      Library.rate_work(scope, movie, 9)
      Reviews.publish(scope, movie, %{"body" => long_body(), "visibility" => "private"})

      assert Repo.reload!(movie).smovie_rating_count == 1
    end

    test "on peut reviewer un episode", %{scope: scope} do
      episode = tv_show_fixture() |> season_fixture() |> episode_fixture()

      assert {:ok, review} = Reviews.publish(scope, episode, %{"body" => "Le meilleur."})
      assert review.work_id == episode.id
    end
  end

  describe "delete/2" do
    test "l'auteur peut supprimer", %{scope: scope, user: user, movie: movie} do
      review = review_fixture(user, movie)

      assert {:ok, _} = Reviews.delete(scope, review)
      assert Repo.reload!(movie).smovie_review_count == 0
    end

    test "un autre membre ne peut pas", %{user: user, movie: movie} do
      review = review_fixture(user, movie)
      autre = Scope.for_user(user_fixture())

      assert Reviews.delete(autre, review) == {:error, :unauthorized}
      assert Repo.get(Review, review.id)
    end
  end

  describe "visible?/2" do
    setup %{user: user, movie: movie} do
      %{autre: user_fixture(), review: review_fixture(user, movie)}
    end

    test "une review publique est visible de tous", %{review: review, autre: autre} do
      assert Reviews.visible?(nil, review)
      assert Reviews.visible?(Scope.for_user(autre), review)
    end

    test "une review privee n'est visible que de son auteur", %{
      user: user,
      movie: movie,
      autre: autre
    } do
      review = review_fixture(user, movie, %{"visibility" => "private"})

      assert Reviews.visible?(Scope.for_user(user), review)
      refute Reviews.visible?(Scope.for_user(autre), review)
      refute Reviews.visible?(nil, review)
    end

    test "une review reservee aux abonnes suit le graphe", %{
      user: user,
      movie: movie,
      autre: autre
    } do
      review = review_fixture(user, movie, %{"visibility" => "followers"})
      autre_scope = Scope.for_user(autre)

      refute Reviews.visible?(autre_scope, review)

      Social.follow(autre_scope, user)

      assert Reviews.visible?(autre_scope, review)
    end
  end

  describe "list_popular_for_work/2" do
    test "classe par likes et ecarte les textes trop courts", %{movie: movie} do
      # Le plancher de longueur ecarte les « bof » d'une ligne qui ont pris
      # deux likes.
      populaire = review_fixture(user_fixture(), movie)
      review_fixture(user_fixture(), movie, %{"body" => "Bof."})

      Repo.update_all(Review, set: [likes_count: 0])
      Repo.update_all(from(r in Review, where: r.id == ^populaire.id), set: [likes_count: 10])

      assert [found] = Reviews.list_popular_for_work(movie)
      assert found.id == populaire.id
    end

    test "ignore les reviews non publiques", %{movie: movie} do
      review_fixture(user_fixture(), movie, %{"visibility" => "private"})

      assert Reviews.list_popular_for_work(movie) == []
    end

    test "cinq auteurs differents au maximum", %{movie: movie} do
      for _ <- 1..8, do: review_fixture(user_fixture(), movie)

      reviews = Reviews.list_popular_for_work(movie)

      assert length(reviews) == 5
      assert reviews |> Enum.map(& &1.user_id) |> Enum.uniq() |> length() == 5
    end
  end

  describe "list_by_user/3" do
    test "un membre voit toutes ses reviews", %{user: user, scope: scope, movie: movie} do
      review_fixture(user, movie, %{"visibility" => "private"})

      assert length(Reviews.list_by_user(scope, user)) == 1
    end

    test "un visiteur ne voit que les publiques", %{user: user, movie: movie} do
      review_fixture(user, movie, %{"visibility" => "private"})
      review_fixture(user, movie_fixture(%{title: "Autre"}), %{"visibility" => "public"})

      assert length(Reviews.list_by_user(nil, user)) == 1
    end

    test "un abonne voit aussi les reviews reservees", %{user: user, movie: movie} do
      review_fixture(user, movie, %{"visibility" => "followers"})
      abonne = Scope.for_user(user_fixture())
      Social.follow(abonne, user)

      assert length(Reviews.list_by_user(abonne, user)) == 1
    end
  end

  describe "excerpt/2" do
    test "coupe sur un mot entier" do
      # Couper au caractere pres produirait des « incroyablem… ».
      review = %Review{body: "Un film absolument remarquable de bout en bout"}

      assert Review.excerpt(review, 20) == "Un film absolument…"
    end

    test "laisse un texte court intact" do
      assert Review.excerpt(%Review{body: "Court"}, 20) == "Court"
    end
  end
end
