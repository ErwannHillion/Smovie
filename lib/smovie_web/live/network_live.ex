defmodule SmovieWeb.NetworkLive do
  @moduledoc """
  Abonnements et abonnes d'un membre.
  """
  use SmovieWeb, :live_view

  alias Smovie.Accounts
  alias Smovie.Social

  @impl true
  def mount(%{"username" => username}, _session, %{assigns: %{live_action: action}} = socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        raise SmovieWeb.ProfileLive.NotFound, username

      user ->
        {:ok,
         socket
         |> assign(user: user, page_title: title(action, user))
         |> assign_members(user, action)}
    end
  end

  defp title(:following, user), do: "#{user.display_name} · abonnements"
  defp title(:followers, user), do: "#{user.display_name} · abonnés"

  defp assign_members(%{assigns: %{current_scope: scope}} = socket, user, action) do
    members = list_members(user, action)

    assign(socket,
      members: members,
      # Une requete par membre pour savoir si on le suit serait absurde sur une
      # liste de cinquante : on charge l'ensemble des suivis une fois.
      following: MapSet.new(Social.following_ids(scope))
    )
  end

  defp list_members(user, :following), do: Social.list_following(user)
  defp list_members(user, :followers), do: Social.list_followers(user)

  @impl true
  def handle_event("toggle_follow", %{"user-id" => user_id}, socket) do
    toggle(socket, user_id)
  end

  defp toggle(%{assigns: %{current_scope: nil}} = socket, _user_id) do
    {:noreply,
     socket
     |> put_flash(:info, gettext("Connectez-vous pour suivre des membres."))
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp toggle(%{assigns: %{current_scope: scope, members: members}} = socket, user_id) do
    case Enum.find(members, &(to_string(&1.id) == user_id)) do
      nil ->
        {:noreply, socket}

      member ->
        Social.toggle_follow(scope, member)
        {:noreply, assign(socket, following: MapSet.new(Social.following_ids(scope)))}
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
      <nav class="text-base-content/50 flex items-center gap-2 py-2 font-mono text-xs">
        <.link navigate={~p"/u/#{@user.username}"} class="hover:text-base-content">
          {@user.display_name}
        </.link>
        <span>/</span>
        <span>{tab_label(@live_action)}</span>
      </nav>

      <h1 class="font-display pb-5 text-3xl leading-none font-bold tracking-tight">
        {tab_label(@live_action)}
      </h1>

      <ul :if={@members != []} class="divide-base-300 border-base-300 divide-y border-t border-b">
        <li :for={member <- @members} class="flex items-center gap-3 py-3">
          <.user_chip user={member} navigate={~p"/u/#{member.username}"} class="flex-1" />
          <button
            :if={followable?(@current_scope, member)}
            type="button"
            phx-click="toggle_follow"
            phx-value-user-id={member.id}
            aria-pressed={to_string(MapSet.member?(@following, member.id))}
            class={[
              "btn btn-xs",
              if(MapSet.member?(@following, member.id), do: "btn-ghost", else: "btn-primary")
            ]}
          >
            {if MapSet.member?(@following, member.id),
              do: gettext("Abonne"),
              else: gettext("Suivre")}
          </button>
        </li>
      </ul>

      <p :if={@members == []} class="text-base-content/50 py-10 text-sm">
        {empty_label(@live_action)}
      </p>
    </Layouts.app>
    """
  end

  defp tab_label(:following), do: gettext("Abonnements")
  defp tab_label(:followers), do: gettext("Abonnes")

  defp empty_label(:following), do: gettext("Ce membre ne suit personne pour l'instant.")
  defp empty_label(:followers), do: gettext("Personne ne suit ce membre pour l'instant.")

  # On ne se propose pas de se suivre soi-meme.
  defp followable?(%{user: %{id: id}}, %{id: id}), do: false
  defp followable?(_scope, _member), do: true
end
