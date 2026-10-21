defmodule Smovie.Config do
  @moduledoc """
  Point de lecture unique de la configuration applicative.

  Aucun autre module n'appelle `Application.get_env/2` sur `:smovie` — le check
  `.credo/no_direct_application_get_env.ex` le verifie.

  Deux raisons. D'abord la tracabilite : une variable renommee se corrige ici,
  pas dans quinze appels disperses. Ensuite la testabilite : une fonction
  nommee se remplace et se documente, une cle de keyword list perdue au milieu
  d'un contexte ne se remplace pas.

  Les valeurs viennent de `config/runtime.exs`, qui est le seul endroit ou
  `System.get_env/2` est appele.
  """

  @app :smovie

  ## TMDB — catalogue, images, casting

  @doc """
  Identifiant TMDB, quel qu'en soit le type.

  TMDB propose deux formes sur la meme page de reglages, et rien ne dit
  laquelle prendre : une **cle API v3** de 32 caracteres, qui se passe en
  parametre `api_key`, et un **jeton de lecture** (JWT) qui se passe en
  en-tete `Authorization: Bearer`. Se tromper donne un 401 sans explication.

  `TMDB_ACCESS_TOKEN` est lu en premier, `TMDB_API_KEY` ensuite : la seconde
  variable existait avant que les deux formes soient acceptees.
  """
  def tmdb_credential do
    case get(:tmdb, :access_token) || get(:tmdb, :api_key) do
      value when is_binary(value) -> classify(String.trim(value))
      _absent -> nil
    end
  end

  # Un jeton de lecture est un JWT : trois segments separes par des points.
  # Une cle v3 est une chaine hexadecimale de 32 caracteres. La distinction
  # est sans ambiguite, et evite de demander a l'utilisateur de la faire.
  defp classify(""), do: nil

  defp classify(value) do
    if String.contains?(value, ".") and length(String.split(value, ".")) == 3 do
      {:bearer, value}
    else
      {:api_key, value}
    end
  end

  @doc "Vrai si un identifiant TMDB est configure."
  def tmdb_configured?, do: not is_nil(tmdb_credential())

  def tmdb_base_url, do: get(:tmdb, :base_url)
  def tmdb_image_base_url, do: get(:tmdb, :image_base_url)
  def tmdb_language, do: get(:tmdb, :language)
  def tmdb_region, do: get(:tmdb, :region)

  @doc """
  Implementation du client TMDB.

  En test, la configuration designe une doublure Mox ; ailleurs, le client Req.
  """
  def tmdb_impl, do: get(:tmdb, :impl) || Smovie.External.TMDB.Req

  ## OMDb — notes presse

  def omdb_api_key, do: get(:omdb, :api_key)
  def omdb_base_url, do: get(:omdb, :base_url)
  def omdb_daily_quota, do: get(:omdb, :daily_quota)
  def omdb_impl, do: get(:omdb, :impl) || Smovie.External.OMDb.Req

  @doc """
  Vrai si les notes presse sont actives.

  Le drapeau permet de couper le fournisseur sans redeploiement : l'application
  affiche alors la note TMDB seule, sans erreur visible.
  """
  def omdb_enabled?, do: get(:omdb, :enabled) == true

  ## Classements et notation

  def trending_window_days, do: get(:trending, :window_days)
  def trending_min_votes, do: get(:trending, :min_votes)

  @doc """
  Poids de l'a priori de la moyenne bayesienne, exprime en nombre de votes.

  Plus il est eleve, plus il faut de notes pour qu'une oeuvre s'ecarte de la
  moyenne de la plateforme.
  """
  def ratings_prior_votes, do: get(:ratings, :prior_votes)

  def popular_reviews_limit, do: get(:reviews, :popular_limit)

  @doc """
  Longueur minimale d'une review pour entrer dans les reviews populaires.

  Ecarte les « bof » d'une ligne qui ont pris deux likes.
  """
  def reviews_min_body_length, do: get(:reviews, :min_body_length)

  ## Langues

  def default_locale, do: get(:i18n, :default_locale)
  def locales, do: get(:i18n, :locales)

  @doc "Vrai si la locale fait partie de celles que l'application sert."
  def supported_locale?(locale) when is_binary(locale), do: locale in locales()
  def supported_locale?(_), do: false

  ## Catalogue

  @doc """
  Vrai si le catalogue doit s'amorcer tout seul au demarrage.

  Coupe en test : une suite ne doit pas mettre de job en file a chaque
  demarrage de l'application.
  """
  def bootstrap_catalog?, do: get(:catalog, :bootstrap_on_boot) == true

  @doc """
  Nombre d'oeuvres en dessous duquel le catalogue est juge trop maigre.
  """
  def bootstrap_threshold, do: get(:catalog, :bootstrap_threshold) || 20

  ## Infrastructure

  def dns_cluster_query, do: Application.get_env(@app, :dns_cluster_query) || :ignore

  @doc """
  Vrai si les messages restent sur la machine au lieu de partir.

  La page de connexion s'en sert pour afficher le lien vers la boite locale :
  en developpement, le lien de connexion n'arrive dans aucune vraie boite.
  """
  def local_mail_adapter?,
    do: Application.get_env(@app, Smovie.Mailer)[:adapter] == Swoosh.Adapters.Local

  def oban, do: Application.fetch_env!(@app, Oban)

  defp get(key, subkey), do: Application.get_env(@app, key)[subkey]
end
