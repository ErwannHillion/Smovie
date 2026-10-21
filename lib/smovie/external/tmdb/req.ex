defmodule Smovie.External.TMDB.Req do
  @moduledoc """
  Client TMDB sur `Req`.

  Trois choses que le client de l'ancienne version ne faisait pas :

  - il accepte indifferemment une cle API v3 et un jeton de lecture, et choisit
    le bon mecanisme d'authentification. TMDB propose les deux sur la meme page
    de reglages, et se tromper donne un 401 sans explication.
  - il renvoie `{:error, :missing_api_key}` au lieu de lever. Une cle absente
    est un probleme de deploiement, pas un bug : l'application doit pouvoir
    afficher une page degradee plutot qu'une erreur 500.
  - il met en cache les reponses de detail. Une fiche consultee dix fois dans
    l'heure ne declenche pas dix appels.
  - il reessaie les erreurs transitoires, et uniquement celles-la : un 404 ne
    se reessaie pas.
  """
  @behaviour Smovie.External.TMDB

  require Logger

  alias Smovie.Config

  @cache :smovie_http_cache
  @cache_ttl :timer.hours(6)
  @receive_timeout 5_000

  # `append_to_response` evite trois appels par fiche : important pour tenir le
  # budget de requetes a l'import.
  @movie_appends "credits,similar,external_ids"
  @tv_appends "credits,similar,external_ids"

  @impl true
  def search_multi(query, opts) do
    get("/search/multi", Keyword.merge([query: query, include_adult: false], opts), cache: false)
  end

  @impl true
  def get_movie(tmdb_id) do
    get("/movie/#{tmdb_id}", append_to_response: @movie_appends)
  end

  @impl true
  def get_tv_show(tmdb_id) do
    get("/tv/#{tmdb_id}", append_to_response: @tv_appends)
  end

  @impl true
  def get_season(tmdb_id, season_number) do
    get("/tv/#{tmdb_id}/season/#{season_number}")
  end

  @impl true
  def trending(type, window) when type in [:movie, :tv] and window in [:day, :week] do
    get("/trending/#{type}/#{window}")
  end

  @impl true
  def now_playing(opts) do
    get("/movie/now_playing", Keyword.put_new(opts, :region, Config.tmdb_region()))
  end

  @impl true
  def on_the_air(opts), do: get("/tv/on_the_air", opts)

  @impl true
  def genres(type) when type in [:movie, :tv], do: get("/genre/#{type}/list")

  defp get(path, params \\ [], opts \\ []) do
    case Config.tmdb_credential() do
      nil -> {:error, :missing_api_key}
      credential -> fetch(path, params, credential, opts)
    end
  end

  defp fetch(path, params, credential, opts) do
    if Keyword.get(opts, :cache, true) do
      cached(cache_key(path, params), fn -> request(path, params, credential) end)
    else
      request(path, params, credential)
    end
  end

  defp cached(key, fun) do
    case Cachex.get(@cache, key) do
      {:ok, nil} ->
        store(key, fun.())

      {:ok, hit} ->
        {:ok, hit}

      # Un cache indisponible ne doit pas empecher l'appel : on degrade en
      # passant outre plutot que d'echouer.
      {:error, _reason} ->
        fun.()
    end
  end

  defp store(key, {:ok, body} = result) do
    Cachex.put(@cache, key, body, expire: @cache_ttl)
    result
  end

  defp store(_key, result), do: result

  defp cache_key(path, params), do: {:tmdb, path, Enum.sort(params)}

  defp request(path, params, credential) do
    params = Keyword.put_new(params, :language, Config.tmdb_language())

    [
      url: Config.tmdb_base_url() <> path,
      receive_timeout: @receive_timeout,
      # :transient ne reessaie que ce qui peut reussir au second essai :
      # un 404 n'en fait pas partie.
      retry: :transient,
      max_retries: 3
    ]
    |> Keyword.merge(authenticate(credential, params))
    |> Req.new()
    |> Req.get()
    |> handle_response(path)
  end

  # Le jeton de lecture passe en en-tete, la cle v3 en parametre : ce sont deux
  # mecanismes d'authentification distincts cote TMDB, pas deux valeurs du
  # meme champ.
  defp authenticate({:bearer, token}, params), do: [params: params, auth: {:bearer, token}]
  defp authenticate({:api_key, key}, params), do: [params: Keyword.put(params, :api_key, key)]

  defp handle_response({:ok, %Req.Response{status: 200, body: body}}, _path), do: {:ok, body}
  defp handle_response({:ok, %Req.Response{status: 404}}, _path), do: {:error, :not_found}

  defp handle_response({:ok, %Req.Response{status: 401}}, path) do
    Logger.error("TMDB a refuse la cle API sur #{path}")
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %Req.Response{status: 429}}, path) do
    Logger.warning("TMDB a limite le debit sur #{path}")
    {:error, :rate_limited}
  end

  defp handle_response({:ok, %Req.Response{status: status}}, path) do
    Logger.error("TMDB a repondu #{status} sur #{path}")
    {:error, :api_error}
  end

  defp handle_response({:error, reason}, path) do
    Logger.error("Appel TMDB #{path} echoue : #{inspect(reason)}")
    {:error, :request_failed}
  end
end
