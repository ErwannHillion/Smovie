defmodule SmovieWeb.Hooks.Locale do
  @moduledoc """
  Pose la locale de la session dans le processus de la LiveView.

  Une LiveView tourne dans son propre processus : la locale posee par
  `SmovieWeb.Plugs.Locale` pendant la requete HTTP n'y est pas visible. Sans ce
  hook, toute page LiveView rend en langue par defaut, quel que soit le
  reglage de l'utilisateur — et le bug ne se voit qu'apres la connexion
  websocket, pas au premier rendu.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  alias Smovie.Config

  def on_mount(:default, _params, session, socket) do
    locale = session["locale"] || Config.default_locale()
    Gettext.put_locale(SmovieWeb.Gettext, locale)

    socket =
      socket
      |> assign(:locale, locale)
      |> assign(:current_path, "/")
      |> attach_hook(:locale_current_path, :handle_params, &put_current_path/3)

    {:cont, socket}
  end

  # Le selecteur de langue renvoie sur la page courante apres le changement :
  # il lui faut le chemin, que seul `handle_params` connait.
  defp put_current_path(_params, uri, socket) do
    {:cont, assign(socket, :current_path, URI.parse(uri).path || "/")}
  end
end
