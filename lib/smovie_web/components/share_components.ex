defmodule SmovieWeb.ShareComponents do
  @moduledoc """
  Feuille de partage vers une conversation.
  """
  use Phoenix.Component
  use Gettext, backend: SmovieWeb.Gettext

  import SmovieWeb.UserComponents

  @doc """
  Feuille modale listant les conversations.

  Elle liste les conversations existantes et non les membres : partager a
  quelqu'un a qui l'on n'a jamais ecrit se fait depuis son profil, ou le
  contexte dit qui c'est.
  """
  attr :conversations, :list, required: true
  attr :selected, :any, required: true
  attr :current_scope, :map, required: true
  attr :title, :string, required: true

  def share_sheet(assigns) do
    ~H"""
    <div class="fixed inset-0 z-[70] flex items-end bg-black/70" phx-click="close_share">
      <div
        class="bg-base-100 border-base-300 max-h-[74%] w-full overflow-y-auto rounded-t-2xl border-t pt-2 pb-6"
        phx-click-away="close_share"
      >
        <div class="bg-base-300 mx-auto mb-3 h-1 w-9 rounded-full"></div>
        <p class="px-4 pb-3 text-sm font-semibold">{@title}</p>

        <ul :if={@conversations != []} class="divide-base-300 divide-y">
          <li :for={conversation <- @conversations} class="flex items-center gap-3 px-4 py-3">
            <.avatar
              :if={other(conversation, @current_scope)}
              user={other(conversation, @current_scope)}
            />
            <span
              :if={is_nil(other(conversation, @current_scope))}
              class="bg-base-300 grid size-9 shrink-0 place-items-center rounded-full text-sm"
            >
              {String.first(conversation.title || "?")}
            </span>
            <span class="min-w-0 flex-1 truncate text-sm">
              {Smovie.Messaging.title(conversation, @current_scope)}
            </span>
            <button
              type="button"
              phx-click="toggle_share"
              phx-value-id={conversation.id}
              aria-pressed={to_string(MapSet.member?(@selected, conversation.id))}
              class={[
                "grid size-11 place-items-center rounded-full border",
                if(MapSet.member?(@selected, conversation.id),
                  do: "bg-smovie border-smovie text-[#190f2b]",
                  else: "border-base-300 text-transparent"
                )
              ]}
            >
              ✓
            </button>
          </li>
        </ul>

        <p :if={@conversations == []} class="text-base-content/50 px-4 py-6 text-sm">
          {gettext("Aucune conversation ouverte. Ecrivez d'abord a quelqu'un.")}
        </p>

        <button
          :if={MapSet.size(@selected) > 0}
          type="button"
          phx-click="confirm_share"
          class="btn btn-primary mx-4 mt-3 w-[calc(100%-2rem)]"
        >
          {send_label(MapSet.size(@selected))}
        </button>
      </div>
    </div>
    """
  end

  defp send_label(count) do
    ngettext("Envoyer a %{count} conversation", "Envoyer a %{count} conversations", count,
      count: count
    )
  end

  defp other(%{kind: :group}, _scope), do: nil

  defp other(conversation, %{user: %{id: me}}) do
    case Enum.find(conversation.members, &(&1.user_id != me)) do
      nil -> nil
      member -> member.user
    end
  end
end
