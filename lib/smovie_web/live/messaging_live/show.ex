defmodule SmovieWeb.MessagingLive.Show do
  @moduledoc """
  Le fil d'une conversation.

  LiveView plutot qu'un Channel : le fil est deja du HTML rendu serveur, et
  les cartes de partage reutilisent les composants des fiches. Un Channel
  obligerait a dupliquer tout ce rendu en JavaScript.
  """
  use SmovieWeb, :live_view

  alias Smovie.Messaging
  alias SmovieWeb.Presence

  @impl true
  def mount(%{"id" => id}, _session, %{assigns: %{current_scope: scope}} = socket) do
    case Messaging.get_conversation(scope, id) do
      {:ok, conversation} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Smovie.PubSub, Messaging.topic(conversation))
          Phoenix.PubSub.subscribe(Smovie.PubSub, Presence.conversation_topic(conversation.id))
          Presence.track_conversation(self(), conversation.id, scope.user)
        end

        Messaging.mark_read(scope, conversation)

        {:ok,
         socket
         |> assign(conversation: conversation, page_title: Messaging.title(conversation, scope))
         |> assign(admin?: Messaging.admin?(scope, conversation))
         |> assign(typing: [])
         |> stream(:messages, Messaging.list_messages(conversation))}

      {:error, reason} ->
        raise SmovieWeb.MessagingLive.NotFound, reason
    end
  end

  @impl true
  def handle_event(
        "send",
        %{"message" => %{"body" => body}},
        %{assigns: %{current_scope: scope, conversation: conversation}} = socket
      ) do
    case Messaging.send_message(scope, conversation, %{"body" => body, "kind" => "text"}) do
      {:ok, _message} -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, error_label(reason))}
    end
  end

  # La frappe s'eteint apres trois secondes d'inactivite : sans minuterie, un
  # indicateur reste allume indefiniment des qu'on abandonne un message.
  def handle_event("typing", _params, %{assigns: %{current_scope: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event(
        "typing",
        _params,
        %{assigns: %{conversation: conversation, current_scope: scope}} = socket
      ) do
    Presence.set_typing(self(), conversation.id, scope.user, true)

    if timer = socket.assigns[:typing_timer], do: Process.cancel_timer(timer)

    {:noreply, assign(socket, typing_timer: Process.send_after(self(), :stop_typing, 3_000))}
  end

  def handle_event(
        "delete",
        %{"id" => id},
        %{assigns: %{current_scope: scope, conversation: conversation}} = socket
      ) do
    case Enum.find(Messaging.list_messages(conversation, limit: 200), &(to_string(&1.id) == id)) do
      nil ->
        {:noreply, socket}

      message ->
        case Messaging.delete_message(scope, message) do
          {:ok, deleted} -> {:noreply, stream_insert(socket, :messages, deleted)}
          {:error, reason} -> {:noreply, put_flash(socket, :error, error_label(reason))}
        end
    end
  end

  @impl true
  def handle_info(
        {:new_message, message},
        %{assigns: %{current_scope: scope, conversation: conversation}} = socket
      ) do
    Messaging.mark_read(scope, conversation)

    {:noreply, stream_insert(socket, :messages, message)}
  end

  def handle_info(
        %{event: "presence_diff"},
        %{assigns: %{conversation: conversation, current_scope: scope}} = socket
      ) do
    {:noreply, assign(socket, typing: Presence.typing_names(conversation.id, scope.user))}
  end

  def handle_info(
        :stop_typing,
        %{assigns: %{conversation: conversation, current_scope: scope}} = socket
      ) do
    Presence.set_typing(self(), conversation.id, scope.user, false)

    {:noreply, assign(socket, typing_timer: nil)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp error_label(:review_not_visible_to_all),
    do: gettext("Cette review n'est pas visible par tous les membres de la conversation.")

  defp error_label(:not_a_member), do: gettext("Vous ne faites pas partie de cette conversation.")
  defp error_label(:left_conversation), do: gettext("Vous avez quitte cette conversation.")
  defp error_label(_reason), do: gettext("Ce message n'a pas pu etre envoye.")

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
      <header class="border-base-300 flex items-center gap-3 border-b py-3">
        <.link navigate={~p"/messages"} class="text-base-content/50 hover:text-base-content">
          <.icon name="hero-chevron-left" class="size-5" />
        </.link>
        <div class="min-w-0">
          <p class="truncate text-sm font-semibold">
            {Messaging.title(@conversation, @current_scope)}
          </p>
          <p class="text-base-content/50 font-mono text-[0.65rem]">{members_label(@conversation)}</p>
        </div>
      </header>

      <div id="messages" phx-update="stream" class="flex flex-col gap-2.5 py-5">
        <div
          :for={{dom_id, message} <- @streams.messages}
          id={dom_id}
          class={["flex max-w-[78%] flex-col", mine?(message, @current_scope) && "self-end"]}
        >
          <p
            :if={not mine?(message, @current_scope) and message.sender}
            class="text-base-content/40 mb-0.5 ml-3 font-mono text-[0.6rem]"
          >
            {message.sender.display_name}
          </p>

          <.message_bubble message={message} mine={mine?(message, @current_scope)} />

          <p class={[
            "text-base-content/40 mt-1 px-1.5 font-mono text-[0.6rem]",
            mine?(message, @current_scope) && "text-right"
          ]}>
            {Calendar.strftime(message.inserted_at, "%H:%M")}
            <button
              :if={deletable?(message, @current_scope, @admin?)}
              type="button"
              phx-click="delete"
              phx-value-id={message.id}
              class="hover:text-heat ml-2"
            >
              {gettext("Supprimer")}
            </button>
          </p>
        </div>
      </div>

      <p
        :if={@typing != []}
        class="text-base-content/50 flex items-center gap-2 px-1 pb-1 font-mono text-[0.65rem]"
      >
        {typing_label(@typing)}
      </p>

      <.form
        for={%{}}
        as={:message}
        id="composer"
        phx-submit="send"
        phx-change="typing"
        class="bg-base-100 border-base-300 sticky bottom-0 flex items-center gap-2 border-t py-3"
      >
        <input
          type="text"
          name="message[body]"
          value=""
          autocomplete="off"
          placeholder={gettext("Un message…")}
          class="bg-base-200 border-base-300 min-h-11 flex-1 rounded-full border px-4 text-sm outline-none"
        />
        <button type="submit" class="btn btn-primary btn-circle btn-sm">
          <.icon name="hero-paper-airplane" class="size-4" />
        </button>
      </.form>
    </Layouts.app>
    """
  end

  attr :message, :map, required: true
  attr :mine, :boolean, required: true

  defp message_bubble(%{message: %{deleted_at: deleted}} = assigns) when not is_nil(deleted) do
    ~H"""
    <p class="bg-base-200 text-base-content/40 rounded-2xl px-3.5 py-2 text-sm italic">
      {gettext("Message supprime")}
    </p>
    """
  end

  defp message_bubble(%{message: %{kind: :work_share, shared_work: work}} = assigns)
       when not is_nil(work) do
    ~H"""
    <.link
      navigate={work_path(@message.shared_work)}
      class="bg-base-200 border-base-300 block w-56 overflow-hidden rounded-2xl border"
    >
      <div class="flex gap-3 p-3">
        <div class="w-12 shrink-0">
          <.poster
            title={@message.shared_work.title}
            poster_path={@message.shared_work.poster_path}
            static
          />
        </div>
        <div class="min-w-0">
          <p class="text-base-content/40 font-mono text-[0.55rem] tracking-[0.12em] uppercase">
            {gettext("Film partage")}
          </p>
          <p class="font-display mt-1 text-base leading-tight font-semibold">
            {@message.shared_work.title}
          </p>
        </div>
      </div>
    </.link>
    """
  end

  defp message_bubble(%{message: %{kind: :review_share, shared_review: review}} = assigns)
       when not is_nil(review) do
    ~H"""
    <.link
      navigate={~p"/review/#{@message.shared_review.id}"}
      class="bg-base-200 border-base-300 block w-60 overflow-hidden rounded-2xl border"
    >
      <div class="flex gap-3 p-3">
        <div class="w-12 shrink-0">
          <.poster
            title={@message.shared_review.work.title}
            poster_path={@message.shared_review.work.poster_path}
            static
          />
        </div>
        <div class="min-w-0">
          <p class="text-base-content/40 font-mono text-[0.55rem] tracking-[0.12em] uppercase">
            {gettext("Review partagee")}
          </p>
          <p class="mt-1 text-sm leading-tight">
            {gettext("par %{member}", member: @message.shared_review.user.display_name)}
          </p>
          <.rating_stars
            :if={@message.shared_review.rating_value}
            value={@message.shared_review.rating_value}
          />
        </div>
      </div>
    </.link>
    """
  end

  # Un partage dont la cible a ete supprimee degrade proprement au lieu de
  # laisser un lien mort.
  defp message_bubble(%{message: %{kind: kind}} = assigns)
       when kind in [:work_share, :review_share] do
    ~H"""
    <p class="bg-base-200 text-base-content/40 rounded-2xl px-3.5 py-2 text-sm italic">
      {gettext("Contenu partage indisponible")}
    </p>
    """
  end

  defp message_bubble(assigns) do
    ~H"""
    <p class={[
      "rounded-2xl px-3.5 py-2 text-sm leading-relaxed whitespace-pre-line",
      @mine && "bg-smovie/15 text-[#ece2fb]",
      !@mine && "bg-base-200"
    ]}>
      {@message.body}
    </p>
    """
  end

  # Au-dela de deux noms, les enumerer prend plus de place que le fil.
  defp typing_label([name]), do: gettext("%{member} ecrit…", member: name)

  defp typing_label([first, second]),
    do: gettext("%{first} et %{second} ecrivent…", first: first, second: second)

  defp typing_label(names), do: gettext("%{count} personnes ecrivent…", count: length(names))

  defp mine?(%{sender_id: sender_id}, %{user: %{id: id}}), do: sender_id == id
  defp mine?(_message, _scope), do: false

  defp deletable?(%{deleted_at: deleted}, _scope, _admin) when not is_nil(deleted), do: false
  defp deletable?(message, scope, admin?), do: mine?(message, scope) or admin?

  defp members_label(%{kind: :group} = conversation) do
    count = conversation |> Messaging.active_members() |> length()

    ngettext("%{count} membre", "%{count} membres", count, count: count)
  end

  defp members_label(_conversation), do: gettext("Conversation privee")

  defp work_path(%{kind: :tv_show, slug: slug}), do: ~p"/serie/#{slug}"
  defp work_path(%{slug: slug}), do: ~p"/film/#{slug}"
end
