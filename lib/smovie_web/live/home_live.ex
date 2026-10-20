defmodule SmovieWeb.HomeLive do
  @moduledoc """
  Page d'accueil.

  Provisoire : SMOVIE-026 y branchera les nouveautes, les tendances, ce qui
  plait aux comptes suivis et les reviews a la une. Elle existe ici pour que
  `/` reste servie apres le retrait des LiveViews de l'ancienne version.
  """
  use SmovieWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Smovie")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      current_path={@current_path}
    >
      <div class="flex max-w-3xl flex-col gap-4 py-10 md:py-16">
        <h1 class="font-display text-5xl font-extrabold leading-none tracking-tight md:text-6xl">
          S<span class="text-smovie">movie</span>
        </h1>
        <p class="text-base-content/70 max-w-prose">
          {gettext(
            "Films et series, notes en demi-etoiles jusqu'a l'episode, reviews, watchlist et messagerie."
          )}
        </p>
        <p class="text-base-content/40 font-mono text-xs">
          {gettext("La page d'accueil arrive avec SMOVIE-026.")}
        </p>
      </div>
    </Layouts.app>
    """
  end
end
