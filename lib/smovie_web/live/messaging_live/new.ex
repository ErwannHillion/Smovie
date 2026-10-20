defmodule SmovieWeb.MessagingLive.New do
  @moduledoc """
  Creation d'une conversation de groupe.

  Les membres se choisissent parmi les comptes suivis : on ne fonde pas un
  groupe avec des inconnus, et proposer tout l'annuaire transformerait la page
  en outil de demarchage.
  """
  use SmovieWeb, :live_view

  alias Smovie.Messaging
  alias Smovie.Social

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    {:ok,
     socket
     |> assign(page_title: gettext("Nouveau groupe"))
     |> assign(candidates: Social.list_following(scope.user, limit: 100))
     |> assign(selected: MapSet.new(), title: "")}
  end

  @impl true
  def handle_event("toggle", %{"user-id" => id}, %{assigns: %{selected: selected}} = socket) do
    selected =
      if MapSet.member?(selected, id),
        do: MapSet.delete(selected, id),
        else: MapSet.put(selected, id)

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("validate", %{"group" => %{"title" => title}}, socket) do
    {:noreply, assign(socket, title: title)}
  end

  def handle_event(
        "create",
        %{"group" => %{"title" => title}},
        %{assigns: %{current_scope: scope, selected: selected, candidates: candidates}} = socket
      ) do
    ids =
      Enum.filter(candidates, &MapSet.member?(selected, to_string(&1.id))) |> Enum.map(& &1.id)

    case Messaging.create_group(scope, String.trim(title), ids) do
      {:ok, conversation} ->
        {:noreply, push_navigate(socket, to: ~p"/messages/#{conversation.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Donnez un nom a ce groupe."))}
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
      unread_count={@unread_count}
      unread_messages={@unread_messages}
    >
      <header class="flex items-center gap-3 py-4">
        <.link navigate={~p"/messages"} class="text-base-content/50 hover:text-base-content">
          <.icon name="hero-chevron-left" class="size-5" />
        </.link>
        <h1 class="font-display text-2xl leading-none font-bold tracking-tight">
          {gettext("Nouveau groupe")}
        </h1>
      </header>

      <.form for={%{}} as={:group} id="group_form" phx-submit="create" phx-change="validate">
        <.input
          type="text"
          name="group[title]"
          value={@title}
          label={gettext("Nom du groupe")}
          required
        />

        <h2 class="text-base-content/70 mt-4 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
          {gettext("Membres")}
        </h2>

        <ul :if={@candidates != []} class="divide-base-300 border-base-300 divide-y border-t border-b">
          <li :for={candidate <- @candidates} class="flex items-center gap-3 py-3">
            <.user_chip user={candidate} class="flex-1" />
            <button
              type="button"
              phx-click="toggle"
              phx-value-user-id={candidate.id}
              aria-pressed={to_string(MapSet.member?(@selected, to_string(candidate.id)))}
              class={[
                "grid size-11 place-items-center rounded-full border",
                selected_class(MapSet.member?(@selected, to_string(candidate.id)))
              ]}
            >
              ✓
            </button>
          </li>
        </ul>

        <p :if={@candidates == []} class="text-base-content/50 py-4 text-sm">
          {gettext("Suivez d'abord quelques membres pour pouvoir les reunir dans un groupe.")}
        </p>

        <.button :if={@candidates != []} variant="primary" class="mt-4">
          {gettext("Creer le groupe")}
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  defp selected_class(true), do: "bg-smovie border-smovie text-[#190f2b]"
  defp selected_class(false), do: "border-base-300 text-transparent"
end
