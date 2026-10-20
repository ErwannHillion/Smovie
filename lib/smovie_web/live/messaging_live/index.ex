defmodule SmovieWeb.MessagingLive.Index do
  @moduledoc """
  Liste des conversations.
  """
  use SmovieWeb, :live_view

  alias Smovie.Messaging

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: gettext("Messages"))
     |> assign_conversations()}
  end

  defp assign_conversations(%{assigns: %{current_scope: scope}} = socket) do
    assign(socket,
      conversations: Messaging.list_conversations(scope),
      unread: Messaging.unread_by_conversation(scope)
    )
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
      <header class="flex items-baseline gap-4 py-4">
        <h1 class="font-display text-3xl leading-none font-bold tracking-tight md:text-4xl">
          {gettext("Messages")}
        </h1>
        <.link navigate={~p"/messages/nouveau"} class="btn btn-primary btn-sm ml-auto">
          {gettext("Nouveau groupe")}
        </.link>
      </header>

      <ul
        :if={@conversations != []}
        class="divide-base-300 border-base-300 divide-y border-t border-b"
      >
        <li :for={conversation <- @conversations}>
          <.link
            navigate={~p"/messages/#{conversation.id}"}
            class="hover:bg-base-200 flex items-center gap-3 px-1 py-3"
          >
            <.conversation_avatar conversation={conversation} current_scope={@current_scope} />
            <span class="min-w-0 flex-1">
              <span class="block truncate text-sm font-medium">
                {Messaging.title(conversation, @current_scope)}
              </span>
              <span class="text-base-content/50 block font-mono text-[0.65rem]">
                {members_label(conversation)}
              </span>
            </span>
            <span
              :if={@unread[conversation.id]}
              class="bg-heat grid min-w-5 place-items-center rounded-full px-1.5 py-0.5 font-mono text-[0.6rem] font-semibold text-[#2a0613]"
            >
              {@unread[conversation.id]}
            </span>
          </.link>
        </li>
      </ul>

      <p :if={@conversations == []} class="text-base-content/50 py-12 text-sm">
        {gettext("Aucune conversation. Ouvrez-en une depuis le profil d'un membre.")}
      </p>
    </Layouts.app>
    """
  end

  attr :conversation, :map, required: true
  attr :current_scope, :map, required: true

  defp conversation_avatar(%{conversation: %{kind: :group}} = assigns) do
    ~H"""
    <span class="bg-base-300 grid size-9 shrink-0 place-items-center rounded-full text-sm">
      {String.first(@conversation.title)}
    </span>
    """
  end

  defp conversation_avatar(assigns) do
    assigns = assign(assigns, :other, other_member(assigns.conversation, assigns.current_scope))

    ~H"""
    <.avatar :if={@other} user={@other} />
    <span :if={is_nil(@other)} class="bg-base-300 size-9 shrink-0 rounded-full"></span>
    """
  end

  defp other_member(conversation, %{user: %{id: me}}) do
    case Enum.find(conversation.members, &(&1.user_id != me)) do
      nil -> nil
      member -> member.user
    end
  end

  defp members_label(%{kind: :group} = conversation) do
    count = conversation |> Messaging.active_members() |> length()

    ngettext("%{count} membre", "%{count} membres", count, count: count)
  end

  defp members_label(_conversation), do: gettext("Conversation privee")
end
