defmodule Smovie.Social.FollowsTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures

  alias Smovie.Accounts
  alias Smovie.Accounts.Scope
  alias Smovie.Repo
  alias Smovie.Social
  alias Smovie.Social.Follow

  setup do
    moi = user_fixture()
    autre = user_fixture()
    %{moi: moi, autre: autre, scope: Scope.for_user(moi)}
  end

  describe "follow/2" do
    test "cree l'abonnement", %{scope: scope, autre: autre} do
      assert {:ok, _follow} = Social.follow(scope, autre)
      assert Social.following?(scope, autre)
    end

    test "est asymetrique", %{scope: scope, autre: autre, moi: moi} do
      # Suivre quelqu'un, c'est choisir de voir son activite, pas lui demander
      # la permission.
      Social.follow(scope, autre)

      refute Social.following?(Scope.for_user(autre), moi)
    end

    test "un second abonnement ne cree pas de doublon", %{scope: scope, autre: autre} do
      Social.follow(scope, autre)
      Social.follow(scope, autre)

      assert Repo.aggregate(Follow, :count) == 1
    end

    test "refuse de se suivre soi-meme", %{scope: scope, moi: moi} do
      assert Social.follow(scope, moi) == {:error, :cannot_follow_self}
    end

    test "la base refuse aussi l'auto-abonnement", %{moi: moi} do
      # La validation applicative seule laisserait passer une insertion directe
      # ou une course.
      assert_raise Postgrex.Error, ~r/follows_not_self/, fn ->
        Repo.insert_all("follows", [
          %{follower_id: moi.id, followed_id: moi.id, inserted_at: DateTime.utc_now(:second)}
        ])
      end
    end

    test "met a jour les deux compteurs", %{scope: scope, moi: moi, autre: autre} do
      Social.follow(scope, autre)

      assert Repo.reload!(moi).following_count == 1
      assert Repo.reload!(autre).followers_count == 1
    end
  end

  describe "unfollow/2" do
    test "retire l'abonnement et remet les compteurs", %{scope: scope, moi: moi, autre: autre} do
      Social.follow(scope, autre)

      assert :ok = Social.unfollow(scope, autre)
      refute Social.following?(scope, autre)
      assert Repo.reload!(moi).following_count == 0
      assert Repo.reload!(autre).followers_count == 0
    end

    test "signale l'absence d'abonnement", %{scope: scope, autre: autre} do
      assert Social.unfollow(scope, autre) == {:error, :not_following}
    end
  end

  describe "toggle_follow/2" do
    test "bascule", %{scope: scope, autre: autre} do
      assert {:ok, :followed} = Social.toggle_follow(scope, autre)
      assert {:ok, :unfollowed} = Social.toggle_follow(scope, autre)
    end
  end

  describe "listes" do
    test "list_following/1 et list_followers/1", %{scope: scope, moi: moi, autre: autre} do
      Social.follow(scope, autre)

      assert [suivi] = Social.list_following(moi)
      assert suivi.id == autre.id
      assert [abonne] = Social.list_followers(autre)
      assert abonne.id == moi.id
    end

    test "following_ids/1 rend une liste d'identifiants", %{scope: scope, autre: autre} do
      Social.follow(scope, autre)

      assert Social.following_ids(scope) == [autre.id]
    end

    test "following_ids/1 rend une liste vide pour un visiteur" do
      assert Social.following_ids(nil) == []
    end
  end

  describe "suggestions/2" do
    test "ne propose ni soi-meme ni les comptes deja suivis", %{
      scope: scope,
      moi: moi,
      autre: autre
    } do
      # Proposer un compte deja suivi est le genre de detail qui fait douter
      # du reste.
      troisieme = user_fixture()
      Social.follow(scope, autre)

      ids = scope |> Social.suggestions() |> Enum.map(& &1.id)

      assert troisieme.id in ids
      refute moi.id in ids
      refute autre.id in ids
    end
  end

  describe "visibilite abonnes" do
    test "un abonne voit un profil reserve aux abonnes", %{scope: scope, moi: moi, autre: autre} do
      autre_scope = Scope.for_user(autre)

      {:ok, autre} =
        Accounts.update_user_visibility(autre_scope, autre, %{"profile_visibility" => "followers"})

      refute Accounts.visible?(scope, autre, :profile)

      Social.follow(scope, autre)

      assert Accounts.visible?(Scope.for_user(moi), autre, :profile)
    end

    test "un visiteur ne voit rien de reserve", %{autre: autre} do
      autre_scope = Scope.for_user(autre)

      {:ok, autre} =
        Accounts.update_user_visibility(autre_scope, autre, %{"profile_visibility" => "followers"})

      refute Accounts.visible?(nil, autre, :profile)
    end
  end
end
