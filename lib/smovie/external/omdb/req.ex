defmodule Smovie.External.OMDb.Req do
  @moduledoc """
  Client OMDb sur `Req`.

  OMDb repond 200 meme sur une erreur, avec `"Response" => "False"` et un
  champ `"Error"` : un code HTTP ne suffit donc pas a savoir si l'appel a
  reussi.
  """
  @behaviour Smovie.External.OMDb

  require Logger

  alias Smovie.Config

  @cache :smovie_http_cache
  @cache_ttl :timer.hours(24)
  @receive_timeout 5_000

  @impl true
  def get_by_imdb_id(imdb_id) do
    with :ok <- check_enabled(),
         {:ok, api_key} <- check_api_key() do
      cached({:omdb, imdb_id}, fn -> request(imdb_id, api_key) end)
    end
  end

  defp check_enabled do
    if Config.omdb_enabled?(), do: :ok, else: {:error, :disabled}
  end

  defp check_api_key do
    case Config.omdb_api_key() do
      key when is_binary(key) and key != "" -> {:ok, key}
      _missing -> {:error, :missing_api_key}
    end
  end

  defp cached(key, fun) do
    case Cachex.get(@cache, key) do
      {:ok, nil} -> store(key, fun.())
      {:ok, hit} -> {:ok, hit}
      {:error, _reason} -> fun.()
    end
  end

  defp store(key, {:ok, body} = result) do
    Cachex.put(@cache, key, body, expire: @cache_ttl)
    result
  end

  defp store(_key, result), do: result

  defp request(imdb_id, api_key) do
    [
      url: Config.omdb_base_url(),
      params: [i: imdb_id, apikey: api_key],
      receive_timeout: @receive_timeout,
      retry: :transient,
      max_retries: 2
    ]
    |> Req.new()
    |> Req.get()
    |> handle_response(imdb_id)
  end

  # OMDb signale ses erreurs dans le corps, pas dans le code HTTP.
  defp handle_response(
         {:ok, %Req.Response{status: 200, body: %{"Response" => "True"} = body}},
         _id
       ),
       do: {:ok, body}

  defp handle_response({:ok, %Req.Response{status: 200, body: %{"Error" => error}}}, imdb_id) do
    if String.contains?(error, "limit") do
      Logger.warning("Quota OMDb atteint sur #{imdb_id}")
      {:error, :quota_exceeded}
    else
      {:error, :not_found}
    end
  end

  defp handle_response({:ok, %Req.Response{status: 401}}, _imdb_id), do: {:error, :unauthorized}

  defp handle_response({:ok, %Req.Response{status: status}}, imdb_id) do
    Logger.error("OMDb a repondu #{status} sur #{imdb_id}")
    {:error, :api_error}
  end

  defp handle_response({:error, reason}, imdb_id) do
    Logger.error("Appel OMDb #{imdb_id} echoue : #{inspect(reason)}")
    {:error, :request_failed}
  end
end
