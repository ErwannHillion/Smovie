defmodule SmovieWeb.LocaleController do
  @moduledoc """
  Changement de langue.

  Un `PUT` plutot qu'un lien : changer de langue modifie l'etat du compte ou du
  navigateur, ce n'est pas une navigation.
  """
  use SmovieWeb, :controller

  alias Smovie.Accounts
  alias Smovie.Config
  alias SmovieWeb.Plugs.Locale

  def update(conn, %{"locale" => locale} = params) do
    if Config.supported_locale?(locale) do
      conn
      |> persist_preference(locale)
      |> Locale.put_locale_cookie(locale)
      |> put_session(:locale, locale)
      |> redirect(to: return_to(params))
    else
      conn
      |> put_flash(:error, gettext("Cette langue n'est pas disponible."))
      |> redirect(to: return_to(params))
    end
  end

  defp persist_preference(%{assigns: %{current_scope: %{user: user}}} = conn, locale) do
    {:ok, _user} = Accounts.update_user_locale(user, locale)
    conn
  end

  defp persist_preference(conn, _locale), do: conn

  # On ne renvoie que vers un chemin interne : une URL absolue venue du
  # formulaire ferait du changement de langue une redirection ouverte.
  defp return_to(%{"return_to" => "/" <> _ = path}), do: path
  defp return_to(_params), do: ~p"/"
end
