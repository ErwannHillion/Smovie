defmodule SmovieWeb.ProfileLive do
  @moduledoc """
  Profil public d'un membre.

  SMOVIE-028 y ajoutera les onglets (films vus, series, reviews, reseau,
  stats) et SMOVIE-029 les statistiques. L'en-tete est pose des maintenant
  parce qu'il donne au username son adresse publique.
  """
  use SmovieWeb, :live_view

  alias Smovie.Accounts
  alias Smovie.Social

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        raise SmovieWeb.ProfileLive.NotFound, username

      user ->
        {:ok, socket |> assign_profile(user) |> assign(page_title: user.display_name)}
    end
  end

  defp assign_profile(%{assigns: %{current_scope: scope}} = socket, user) do
    assign(socket,
      user: user,
      visible: Accounts.visible?(scope, user, :profile),
      following?: Social.following?(scope, user)
    )
  end

  @impl true
  def handle_event("toggle_follow", _params, %{assigns: %{current_scope: nil}} = socket) do
    {:noreply,
     socket
     |> put_flash(:info, gettext("Connectez-vous pour suivre des membres."))
     |> push_navigate(to: ~p"/users/log-in")}
  end

  def handle_event(
        "toggle_follow",
        _params,
        %{assigns: %{current_scope: scope, user: user}} = socket
      ) do
    Social.toggle_follow(scope, user)

    {:noreply, assign_profile(socket, Smovie.Repo.reload!(user))}
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
          <p class="text-base-content/70 mt-2 flex gap-4 font-mono text-xs">
            <.link navigate={~p"/u/#{@user.username}/abonnements"} class="hover:text-base-content">
              <b class="text-base-content">{@user.following_count}</b> {gettext("abonnements")}
            </.link>
            <.link navigate={~p"/u/#{@user.username}/abonnes"} class="hover:text-base-content">
              <b class="text-base-content">{@user.followers_count}</b> {gettext("abonnes")}
            </.link>
          </p>
          <p
            :if={@visible and @user.bio}
            class="text-base-content/80 mt-3 max-w-prose text-sm leading-relaxed"
          >
            {@user.bio}
          </p>
        </div>
        <div class="flex items-center gap-2 md:ml-auto">
          <.link
            :if={own_profile?(@current_scope, @user)}
            navigate={~p"/users/settings"}
            class="btn btn-ghost btn-sm"
          >
            {gettext("Modifier mon profil")}
          </.link>
          <button
            :if={not own_profile?(@current_scope, @user)}
            type="button"
            phx-click="toggle_follow"
            aria-pressed={to_string(@following?)}
            class={["btn btn-sm", if(@following?, do: "btn-ghost", else: "btn-primary")]}
          >
            {if @following?, do: gettext("Abonne"), else: gettext("Suivre")}
          </button>
        </div>
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
