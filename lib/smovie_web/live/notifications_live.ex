defmodule SmovieWeb.NotificationsLive do
  @moduledoc """
  Les notifications d'un membre.
  """
  use SmovieWeb, :live_view

  alias Smovie.Social

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    {:ok,
     socket
     |> assign(page_title: gettext("Notifications"))
     |> assign(notifications: Social.list_notifications(scope))}
  end

  @impl true
  def handle_event("mark_all_read", _params, %{assigns: %{current_scope: scope}} = socket) do
    Social.mark_all_read(scope)

    {:noreply, assign(socket, notifications: Social.list_notifications(scope))}
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
      unread_messages={@unread_messages}
    >
      <header class="flex items-baseline gap-4 py-4">
        <h1 class="font-display text-3xl leading-none font-bold tracking-tight">
          {gettext("Notifications")}
        </h1>
        <button
          :if={Enum.any?(@notifications, &is_nil(&1.read_at))}
          type="button"
          phx-click="mark_all_read"
          class="btn btn-ghost btn-xs ml-auto"
        >
          {gettext("Tout marquer comme lu")}
        </button>
      </header>

      <ul
        :if={@notifications != []}
        class="divide-base-300 border-base-300 divide-y border-t border-b"
      >
        <li
          :for={notification <- @notifications}
          class={["flex items-center gap-3 py-3", is_nil(notification.read_at) && "bg-smovie/5"]}
        >
          <.avatar :if={notification.actor} user={notification.actor} />
          <div class="min-w-0 flex-1">
            <p class="text-sm leading-tight">{sentence(notification)}</p>
            <p class="text-base-content/50 mt-1 font-mono text-[0.65rem]">
              {Calendar.strftime(notification.inserted_at, "%d/%m/%Y")}
            </p>
          </div>
          <.link
            :if={notification.review_id}
            navigate={~p"/review/#{notification.review_id}"}
            class="text-base-content/40 hover:text-base-content shrink-0"
          >
            <.icon name="hero-chevron-right" class="size-4" />
          </.link>
        </li>
      </ul>

      <p :if={@notifications == []} class="text-base-content/50 py-12 text-sm">
        {gettext("Aucune notification pour l'instant.")}
      </p>
    </Layouts.app>
    """
  end

  # Phrases completes par nature, comme pour le fil : assembler des fragments
  # rendrait la traduction impossible.
  defp sentence(%{kind: :new_follower, actor: actor}),
    do: gettext("%{member} s'est abonne a votre profil", member: name(actor))

  defp sentence(%{kind: :review_liked, actor: actor}),
    do: gettext("%{member} a aime votre review", member: name(actor))

  defp sentence(%{kind: :review_commented, actor: actor}),
    do: gettext("%{member} a commente votre review", member: name(actor))

  defp sentence(%{kind: :comment_replied, actor: actor}),
    do: gettext("%{member} a repondu a votre commentaire", member: name(actor))

  defp sentence(%{kind: :new_message, actor: actor}),
    do: gettext("%{member} vous a envoye un message", member: name(actor))

  defp sentence(%{kind: :friend_rated_watchlist, actor: actor, work: work}),
    do:
      gettext("%{member} a note %{work}, qui est dans votre liste a voir",
        member: name(actor),
        work: work_title(work)
      )

  defp sentence(_notification), do: ""

  # Un compte supprime laisse ses notifications derriere lui : mieux vaut un
  # libelle neutre qu'une page en erreur.
  defp name(nil), do: gettext("Un membre")
  defp name(actor), do: actor.display_name

  defp work_title(nil), do: gettext("une oeuvre")
  defp work_title(work), do: work.title
end
