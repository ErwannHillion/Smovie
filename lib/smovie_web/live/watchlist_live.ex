defmodule SmovieWeb.WatchlistLive do
  @moduledoc """
  La liste a voir d'un membre.
  """
  use SmovieWeb, :live_view

  alias Smovie.Catalog
  alias Smovie.Catalog.Work
  alias Smovie.Library

  @sorts ~w(added release rating runtime title)
  @kinds ~w(movie tv_show)

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    {:ok, assign(socket, owner: scope.user, page_title: gettext("Watchlist"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket |> assign(sort: sort_from(params), kind: kind_from(params)) |> assign_items()}
  end

  # Tri et filtre viennent de l'URL : une valeur inconnue retombe sur le
  # defaut plutot que de lever.
  defp sort_from(%{"tri" => sort}) when sort in @sorts, do: String.to_existing_atom(sort)
  defp sort_from(_params), do: :added

  defp kind_from(%{"type" => kind}) when kind in @kinds, do: String.to_existing_atom(kind)
  defp kind_from(_params), do: nil

  defp assign_items(%{assigns: %{owner: owner, sort: sort, kind: kind}} = socket) do
    assign(socket,
      works: Library.list_watchlist(owner, sort: sort, kind: kind),
      count: Library.watchlist_count(owner),
      minutes: Library.watchlist_minutes(owner)
    )
  end

  @impl true
  def handle_event("remove", %{"slug" => slug}, %{assigns: %{current_scope: scope}} = socket) do
    case Catalog.get_work_by_slug(slug) do
      nil ->
        {:noreply, socket}

      work ->
        Library.remove_from_watchlist(scope, work)
        {:noreply, assign_items(socket)}
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
      <header class="flex flex-wrap items-baseline gap-x-4 gap-y-1 py-4">
        <h1 class="font-display text-3xl leading-none font-bold tracking-tight md:text-4xl">
          {gettext("Watchlist")}
        </h1>
        <p class="text-base-content/50 font-mono text-xs">{summary(@count, @minutes)}</p>
      </header>

      <div class="flex flex-wrap gap-2 pb-4">
        <.link
          :for={{value, label} <- sorts()}
          patch={~p"/watchlist?tri=#{value}&type=#{@kind || ""}"}
          aria-pressed={to_string(@sort == value)}
          class={chip_class(@sort == value)}
        >
          {label}
        </.link>
      </div>

      <div class="flex flex-wrap gap-2 pb-6">
        <.link
          :for={{value, label} <- kinds()}
          patch={~p"/watchlist?tri=#{@sort}&type=#{value || ""}"}
          aria-pressed={to_string(@kind == value)}
          class={chip_class(@kind == value)}
        >
          {label}
        </.link>
      </div>

      <.poster_grid :if={@works != []}>
        <div :for={work <- @works} class="relative">
          <.poster
            title={work.title}
            poster_path={work.poster_path}
            rating={half_stars(work)}
            navigate={work_path(work)}
            class="w-full"
          />
          <button
            type="button"
            phx-click="remove"
            phx-value-slug={work.slug}
            aria-label={gettext("Retirer de la liste")}
            class="bg-base-100/80 absolute top-1 right-1 grid size-11 place-items-center rounded-full text-sm"
          >
            ✕
          </button>
        </div>
      </.poster_grid>

      <p :if={@works == []} class="text-base-content/50 py-12 text-sm">
        {empty_label(@count)}
      </p>
    </Layouts.app>
    """
  end

  defp sorts do
    [
      {:added, gettext("Date d'ajout")},
      {:release, gettext("Sortie")},
      {:rating, gettext("Note Smovie")},
      {:runtime, gettext("Duree")},
      {:title, gettext("Titre")}
    ]
  end

  defp kinds do
    [{nil, gettext("Tout")}, {:movie, gettext("Films")}, {:tv_show, gettext("Series")}]
  end

  defp chip_class(true),
    do:
      "bg-smovie/15 border-smovie/45 text-smovie min-h-11 rounded-full border px-3.5 py-2 text-xs"

  defp chip_class(false),
    do:
      "bg-base-200 text-base-content/60 hover:text-base-content min-h-11 rounded-full border border-transparent px-3.5 py-2 text-xs"

  # Les deux chiffres ensemble : savoir qu'on a trente films a voir ne dit pas
  # combien de soirees cela represente.
  defp summary(0, _minutes), do: ""

  defp summary(count, minutes) do
    ngettext("%{count} oeuvre", "%{count} oeuvres", count, count: count) <>
      " · " <>
      gettext("%{hours} h %{rest} de visionnage", hours: div(minutes, 60), rest: rem(minutes, 60))
  end

  # Une liste filtree vide et une liste vide ne disent pas la meme chose.
  defp empty_label(0),
    do: gettext("Votre liste a voir est vide. Ajoutez un film depuis sa fiche.")

  defp empty_label(_count), do: gettext("Aucune oeuvre ne correspond a ce filtre.")

  defp half_stars(work), do: Work.smovie_half_stars(work, Catalog.min_votes())

  defp work_path(%Work{kind: :tv_show, slug: slug}), do: ~p"/serie/#{slug}"
  defp work_path(%Work{slug: slug}), do: ~p"/film/#{slug}"
end
