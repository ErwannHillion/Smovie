defmodule Smovie.AccountsProfileTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures

  alias Smovie.Accounts
  alias Smovie.Accounts.Scope
  alias Smovie.Accounts.User

  describe "username derive a l'inscription" do
    test "vient de la partie locale de l'adresse" do
      {:ok, user} = Accounts.register_user(%{email: "jeanne.dupont@exemple.fr"})

      assert user.username == "jeannedupont"
      assert user.display_name == "jeanne.dupont"
    end

    test "ajoute un suffixe en cas de collision" do
      {:ok, first} = Accounts.register_user(%{email: "martin@exemple.fr"})
      {:ok, second} = Accounts.register_user(%{email: "martin@autre.fr"})

      assert first.username == "martin"
      assert second.username == "martin2"
    end

    test "complete un identifiant trop court" do
      {:ok, user} = Accounts.register_user(%{email: "jo@exemple.fr"})

      assert user.username == "jo0"
      assert String.length(user.username) >= 3
    end

    test "ecarte les identifiants reserves" do
      {:ok, user} = Accounts.register_user(%{email: "admin@exemple.fr"})

      refute user.username == "admin"
      assert user.username == "admin2"
    end
  end

  describe "update_user_profile/3" do
    setup do
      user = user_fixture()
      %{user: user, scope: Scope.for_user(user)}
    end

    test "met a jour le profil de son proprietaire", %{user: user, scope: scope} do
      {:ok, updated} =
        Accounts.update_user_profile(scope, user, %{
          "username" => "cinephile",
          "display_name" => "Cinephile",
          "bio" => "Je note tout.",
          "location" => "Montpellier"
        })

      assert updated.username == "cinephile"
      assert updated.bio == "Je note tout."
    end

    test "refuse de modifier le profil d'un autre membre", %{scope: scope} do
      autre = user_fixture()

      assert Accounts.update_user_profile(scope, autre, %{"display_name" => "Pirate"}) ==
               {:error, :unauthorized}

      assert Accounts.get_user!(autre.id).display_name == autre.display_name
    end

    test "normalise la casse de l'identifiant", %{user: user, scope: scope} do
      {:ok, updated} =
        Accounts.update_user_profile(scope, user, %{
          "username" => "CineFiL",
          "display_name" => user.display_name
        })

      assert updated.username == "cinefil"
    end

    test "refuse un identifiant deja pris", %{user: user, scope: scope} do
      autre = user_fixture()

      {:error, changeset} =
        Accounts.update_user_profile(scope, user, %{
          "username" => autre.username,
          "display_name" => user.display_name
        })

      assert "has already been taken" in errors_on(changeset).username
    end

    test "refuse un identifiant reserve", %{user: user, scope: scope} do
      {:error, changeset} =
        Accounts.update_user_profile(scope, user, %{
          "username" => "support",
          "display_name" => user.display_name
        })

      assert "n'est pas disponible" in errors_on(changeset).username
    end

    test "refuse les caracteres hors de l'alphabet autorise", %{user: user, scope: scope} do
      for invalide <- ["jean dupont", "jean-dupont", "jéròme", "jean.dupont"] do
        {:error, changeset} =
          Accounts.update_user_profile(scope, user, %{
            "username" => invalide,
            "display_name" => user.display_name
          })

        assert errors_on(changeset)[:username], "#{invalide} aurait du etre refuse"
      end
    end

    test "refuse un identifiant trop court ou trop long", %{user: user, scope: scope} do
      for invalide <- ["ab", String.duplicate("a", 31)] do
        {:error, changeset} =
          Accounts.update_user_profile(scope, user, %{
            "username" => invalide,
            "display_name" => user.display_name
          })

        assert errors_on(changeset)[:username]
      end
    end

    test "borne la bio a 500 caracteres", %{user: user, scope: scope} do
      {:error, changeset} =
        Accounts.update_user_profile(scope, user, %{
          "username" => user.username,
          "display_name" => user.display_name,
          "bio" => String.duplicate("a", 501)
        })

      assert errors_on(changeset)[:bio]
    end
  end

  describe "contrainte de base" do
    test "la base refuse un format invalide meme sans passer par le changeset" do
      # La validation applicative seule laisserait passer une insertion directe
      # ou une course entre deux inscriptions simultanees.
      user = user_fixture()

      assert_raise Postgrex.Error, fn ->
        Smovie.Repo.update_all(
          from(u in User, where: u.id == ^user.id),
          set: [username: "Jean Dupont"]
        )
      end
    end
  end

  describe "get_user_by_username/1" do
    test "trouve un membre quelle que soit la casse" do
      user = user_fixture()

      assert Accounts.get_user_by_username(user.username).id == user.id
      assert Accounts.get_user_by_username(String.upcase(user.username)).id == user.id
    end

    test "renvoie nil pour un inconnu" do
      refute Accounts.get_user_by_username("personne_ici")
    end
  end
end
