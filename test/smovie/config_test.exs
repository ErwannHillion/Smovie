defmodule Smovie.ConfigTest do
  # Plusieurs cas remplacent temporairement la configuration applicative, qui
  # est globale au noeud : la suite ne peut pas tourner en parallele.
  use ExUnit.Case, async: false

  alias Smovie.Config

  describe "TMDB" do
    test "expose les valeurs de config/runtime.exs" do
      assert Config.tmdb_base_url() == "https://api.themoviedb.org/3"
      assert Config.tmdb_image_base_url() == "https://image.tmdb.org/t/p"
      assert Config.tmdb_language() == "fr-FR"
      assert Config.tmdb_region() == "FR"
    end

    test "tmdb_configured?/0 est faux sans identifiant" do
      with_env(:tmdb, [api_key: nil, access_token: nil], fn ->
        refute Config.tmdb_configured?()
        assert Config.tmdb_credential() == nil
      end)
    end

    test "tmdb_configured?/0 est faux sur une valeur vide ou blanche" do
      for valeur <- ["", "   "] do
        with_env(:tmdb, [api_key: valeur, access_token: nil], fn ->
          refute Config.tmdb_configured?()
        end)
      end
    end

    test "reconnait une cle v3 a sa forme" do
      # 32 caracteres hexadecimaux : elle se passe en parametre api_key.
      with_env(:tmdb, [api_key: "3b27f2809e11b60591c81a8eb4014c35", access_token: nil], fn ->
        assert Config.tmdb_credential() == {:api_key, "3b27f2809e11b60591c81a8eb4014c35"}
      end)
    end

    test "reconnait un jeton de lecture a sa forme" do
      # Un JWT a trois segments separes par des points : il se passe en
      # en-tete Authorization: Bearer. Se tromper de mecanisme donne un 401
      # sans explication, d'ou la detection automatique.
      jeton = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature"

      with_env(:tmdb, [access_token: jeton, api_key: nil], fn ->
        assert Config.tmdb_credential() == {:bearer, jeton}
      end)
    end

    test "le jeton l'emporte quand les deux sont renseignes" do
      jeton = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature"

      with_env(:tmdb, [access_token: jeton, api_key: "3b27f2809e11b60591c81a8eb4014c35"], fn ->
        assert Config.tmdb_credential() == {:bearer, jeton}
      end)
    end

    test "ignore les espaces autour de la valeur" do
      # Une valeur copiee-collee depuis la page TMDB traine souvent un espace
      # ou un retour a la ligne.
      with_env(:tmdb, [api_key: "  abc123  ", access_token: nil], fn ->
        assert Config.tmdb_credential() == {:api_key, "abc123"}
      end)
    end

    test "tmdb_impl/0 retombe sur le client Req quand rien n'est configure" do
      with_env(:tmdb, [impl: nil], fn ->
        assert Config.tmdb_impl() == Smovie.External.TMDB.Req
      end)
    end
  end

  describe "OMDb" do
    test "omdb_enabled?/0 est faux par defaut" do
      refute Config.omdb_enabled?()
    end

    test "omdb_enabled?/0 n'accepte que le booleen vrai" do
      with_env(:omdb, [enabled: "true"], fn -> refute Config.omdb_enabled?() end)
      with_env(:omdb, [enabled: true], fn -> assert Config.omdb_enabled?() end)
    end

    test "le quota journalier est un entier" do
      assert is_integer(Config.omdb_daily_quota())
    end
  end

  describe "classements et notation" do
    test "les seuils sont des entiers" do
      assert is_integer(Config.trending_window_days())
      assert is_integer(Config.trending_min_votes())
      assert is_integer(Config.ratings_prior_votes())
      assert is_integer(Config.popular_reviews_limit())
      assert is_integer(Config.reviews_min_body_length())
    end
  end

  describe "langues" do
    test "le francais est la langue par defaut" do
      assert Config.default_locale() == "fr"
    end

    test "le francais et l'anglais sont servis" do
      assert Config.locales() == ["fr", "en"]
    end

    test "supported_locale?/1 reconnait les locales servies" do
      assert Config.supported_locale?("fr")
      assert Config.supported_locale?("en")
      refute Config.supported_locale?("de")
    end

    test "supported_locale?/1 refuse ce qui n'est pas une chaine" do
      refute Config.supported_locale?(:fr)
      refute Config.supported_locale?(nil)
    end
  end

  describe "infrastructure" do
    test "dns_cluster_query/0 retombe sur :ignore" do
      assert Config.dns_cluster_query() == :ignore
    end

    test "local_mail_adapter?/0 ne reconnait que l'adaptateur local" do
      # En test, l'adaptateur est Swoosh.Adapters.Test : il n'y a pas de boite
      # locale a proposer, contrairement au developpement.
      refute Config.local_mail_adapter?()

      with_env_module(Smovie.Mailer, [adapter: Swoosh.Adapters.Local], fn ->
        assert Config.local_mail_adapter?()
      end)
    end

    test "oban/0 expose la configuration des files" do
      config = Config.oban()

      assert config[:repo] == Smovie.Repo
      assert config[:testing] == :manual
    end
  end

  defp with_env_module(key, overrides, fun) do
    original = Application.get_env(:smovie, key)
    Application.put_env(:smovie, key, Keyword.merge(original || [], overrides))

    try do
      fun.()
    after
      Application.put_env(:smovie, key, original)
    end
  end

  # Remplace temporairement quelques cles, et restaure l'etat d'origine.
  #
  # `original` est lu avant le `try` : une variable liee dans le corps d'un
  # `try` n'est pas visible depuis son `after`.
  defp with_env(key, overrides, fun) do
    original = Application.get_env(:smovie, key)
    Application.put_env(:smovie, key, Keyword.merge(original || [], overrides))

    try do
      fun.()
    after
      Application.put_env(:smovie, key, original)
    end
  end
end
