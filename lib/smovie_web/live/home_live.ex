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
    <main class="mx-auto flex min-h-dvh max-w-2xl flex-col justify-center gap-4 px-4 py-16">
      <h1 class="text-3xl font-semibold">Smovie</h1>
      <p class="text-base-content/70">
        Films et series, notes en demi-etoiles jusqu'a l'episode, reviews, watchlist
        et messagerie.
      </p>
      <p class="text-base-content/50 text-sm">
        Reconstruction en cours. La page d'accueil arrive avec SMOVIE-026.
      </p>
    </main>
    """
  end
end
