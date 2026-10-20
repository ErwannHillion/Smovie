defmodule SmovieWeb.SoonLive do
  @moduledoc """
  Panneau d'attente des sections pas encore construites.

  La navigation definitive est posee des maintenant : une barre qui mene a des
  404 serait plus deroutante qu'une barre qui annonce ce qui arrive. Chaque
  entree nomme le ticket qui la remplira.
  """
  use SmovieWeb, :live_view

  @sections %{
    reviews:
      {"Reviews", "SMOVIE-022",
       "Les reviews populaires, celles de vos abonnements, et les plus recentes."},
    watchlist:
      {"Watchlist", "SMOVIE-015", "Votre liste a voir, triable par sortie, duree et note Smovie."},
    messages:
      {"Messages", "SMOVIE-030",
       "Conversations privees et groupes, avec partage de films et de reviews."},
    search:
      {"Recherche", "SMOVIE-027", "Recherche plein texte sur le catalogue, completee par TMDB."}
  }

  @impl true
  def mount(_params, _session, %{assigns: %{live_action: section}} = socket) do
    {title, ticket, description} = Map.fetch!(@sections, section)

    {:ok,
     assign(socket, page_title: title, title: title, ticket: ticket, description: description)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      current_path={@current_path}
      unread_count={@unread_count}
    >
      <div class="flex max-w-xl flex-col items-start gap-3 py-16">
        <p class="text-base-content/40 font-mono text-[0.65rem] tracking-[0.15em] uppercase">
          {@ticket}
        </p>
        <h1 class="font-display text-4xl font-bold leading-none tracking-tight">{@title}</h1>
        <p class="text-base-content/70">{@description}</p>
        <.link navigate={~p"/"} class="btn btn-primary btn-sm mt-2">
          {gettext("Retour a l'accueil")}
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
