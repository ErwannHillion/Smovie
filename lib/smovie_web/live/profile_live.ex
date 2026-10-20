defmodule SmovieWeb.ProfileLive do
  @moduledoc """
  Profil public d'un membre.

  SMOVIE-028 y ajoutera les onglets (films vus, series, reviews, reseau,
  stats) et SMOVIE-029 les statistiques. L'en-tete est pose des maintenant
  parce qu'il donne au username son adresse publique.
  """
  use SmovieWeb, :live_view

  alias Smovie.Accounts

  @impl true
  def mount(%{"username" => username}, _session, %{assigns: %{current_scope: scope}} = socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        raise SmovieWeb.ProfileLive.NotFound, username

      user ->
        {:ok,
         assign(socket,
           user: user,
           visible: Accounts.visible?(scope, user, :profile),
           page_title: user.display_name
         )}
    end
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
      <header class="flex flex-col gap-4 py-6 md:flex-row md:items-center md:gap-6 md:py-10">
        <.avatar user={@user} size={:large} />
        <div class="min-w-0">
          <h1 class="font-display text-3xl font-bold leading-none tracking-tight md:text-4xl">
            {@user.display_name}
          </h1>
          <p class="text-base-content/50 mt-1.5 font-mono text-xs">
            @{@user.username}<span :if={@visible and @user.location}> · {@user.location}</span>
          </p>
          <p
            :if={@visible and @user.bio}
            class="text-base-content/80 mt-3 max-w-prose text-sm leading-relaxed"
          >
            {@user.bio}
          </p>
        </div>
        <.link
          :if={own_profile?(@current_scope, @user)}
          navigate={~p"/users/settings"}
          class="btn btn-ghost btn-sm md:ml-auto"
        >
          {gettext("Modifier mon profil")}
        </.link>
      </header>

      <div class="border-base-300 border-t pt-6">
        <p :if={@visible} class="text-base-content/40 font-mono text-xs">
          {gettext("Films vus, series, reviews et statistiques arrivent avec SMOVIE-028.")}
        </p>
        <p :if={not @visible} class="text-base-content/60 flex items-center gap-2 text-sm">
          <.icon name="hero-lock-closed" class="size-4" />
          {gettext("Ce profil est prive.")}
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp own_profile?(%{user: %{id: id}}, %{id: id}), do: true
  defp own_profile?(_scope, _user), do: false
end
