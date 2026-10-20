defmodule Smovie.AccountsVisibilityTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures

  alias Smovie.Accounts
  alias Smovie.Accounts.Scope
  alias Smovie.Accounts.Visibility

  setup do
    owner = user_fixture()
    other = user_fixture()

    %{
      owner: owner,
      other: other,
      owner_scope: Scope.for_user(owner),
      other_scope: Scope.for_user(other)
    }
  end

  describe "valeurs par defaut" do
    test "un nouveau compte est public", %{owner: owner} do
      assert owner.profile_visibility == :public
      assert owner.watchlist_visibility == :public
      assert owner.default_review_visibility == :public
    end
  end

  describe "visible?/3" do
    test "le proprietaire voit toujours ses donnees", %{owner: owner, owner_scope: scope} do
      {:ok, owner} =
        Accounts.update_user_visibility(scope, owner, %{"profile_visibility" => "private"})

      assert Accounts.visible?(Scope.for_user(owner), owner, :profile)
    end

    test "un profil public est visible par un visiteur non connecte", %{owner: owner} do
      assert Accounts.visible?(nil, owner, :profile)
    end

    test "un profil prive est invisible pour les autres", %{
      owner: owner,
      owner_scope: scope,
      other_scope: other_scope
    } do
      {:ok, owner} =
        Accounts.update_user_visibility(scope, owner, %{"profile_visibility" => "private"})

      refute Accounts.visible?(other_scope, owner, :profile)
      refute Accounts.visible?(nil, owner, :profile)
    end

    test "le reglage abonnes ferme l'acces tant que personne ne suit personne",
         %{owner: owner, owner_scope: scope, other_scope: other_scope} do
      # Les abonnements arrivent avec SMOVIE-019 : d'ici la, personne n'est
      # abonne, donc le resultat est bien « invisible ».
      {:ok, owner} =
        Accounts.update_user_visibility(scope, owner, %{"profile_visibility" => "followers"})

      refute Accounts.visible?(other_scope, owner, :profile)
      assert Accounts.visible?(Scope.for_user(owner), owner, :profile)
    end

    test "la watchlist a son propre reglage", %{
      owner: owner,
      owner_scope: scope,
      other_scope: other
    } do
      {:ok, owner} =
        Accounts.update_user_visibility(scope, owner, %{"watchlist_visibility" => "private"})

      assert Accounts.visible?(other, owner, :profile)
      refute Accounts.visible?(other, owner, :watchlist)
    end
  end

  describe "update_user_visibility/3" do
    test "refuse de modifier les reglages d'un autre", %{owner: owner, other_scope: scope} do
      assert Accounts.update_user_visibility(scope, owner, %{"profile_visibility" => "private"}) ==
               {:error, :unauthorized}
    end

    test "refuse une valeur inventee", %{owner: owner, owner_scope: scope} do
      {:error, changeset} =
        Accounts.update_user_visibility(scope, owner, %{"profile_visibility" => "amis_damis"})

      assert errors_on(changeset)[:profile_visibility]
    end
  end

  describe "Visibility" do
    test "expose trois valeurs, de la plus ouverte a la plus fermee" do
      assert Visibility.values() == [:public, :followers, :private]
    end

    test "fournit des options traduites pour les formulaires" do
      assert [{label, :public} | _] = Visibility.options()
      assert is_binary(label)
    end
  end
end
