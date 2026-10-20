defmodule SmovieWeb.SearchLive do
  @moduledoc """
  Recherche dans le catalogue et chez les membres.
  """
  use SmovieWeb, :live_view

  alias Smovie.Accounts
  alias Smovie.Catalog
  alias Smovie.Catalog.Work

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Recherche"), importing: nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    term = params |> Map.get("q", "") |> String.trim()

    {:noreply, socket |> assign(term: term) |> assign_results(term)}
  end

  defp assign_results(socket, "") do
    assign(socket, works: [], members: [])
  end

  defp assign_results(socket, term) do
    assign(socket,
      works: Catalog.search_everywhere(term),
      members: Accounts.search_members(term)
    )
  end

  @impl true
  def handle_event("search", %{"q" => term}, socket) do
    {:noreply, push_patch(socket, to: ~p"/recherche?q=#{term}")}
  end

  # L'import est synchrone, et c'est voulu : on vient de cliquer sur une
  # oeuvre precise, et la page suivante est sa fiche. La mettre en file
  # obligerait a attendre sans savoir quoi.
  def handle_event("import", %{"kind" => kind, "tmdb-id" => tmdb_id}, socket) do
    case Catalog.import_work(kind, tmdb_id) do
      {:ok, work} ->
        {:noreply, push_navigate(socket, to: work_path(work))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Cette oeuvre n'a pas pu etre importee."))}
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
      <form id="search-form" phx-change="search" phx-submit="search" class="py-4">
        <label class="sr-only" for="search-input">{gettext("Rechercher")}</label>
        <div class="bg-base-200 border-base-300 flex items-center gap-3 rounded-xl border px-4">
          <.icon name="hero-magnifying-glass" class="text-base-content/40 size-5 shrink-0" />
          <input
            id="search-input"
            type="search"
            name="q"
            value={@term}
            autocomplete="off"
            phx-debounce="250"
            placeholder={gettext("Un film, une serie, un membre…")}
            class="min-h-12 w-full bg-transparent text-base outline-none"
          />
        </div>
      </form>

      <p :if={@term != "" and String.length(@term) < 3} class="text-base-content/50 py-6 text-sm">
        {gettext("Entrez au moins trois caracteres.")}
      </p>

      <section :if={@works != []} class="pb-8">
        <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
          {gettext("Films et series")}
        </h2>
        <ul class="divide-base-300 border-base-300 mt-2 divide-y border-t border-b">
          <li :for={result <- @works} class="flex items-center gap-3 py-3">
            <div class="w-10 shrink-0">
              <.poster
                title={result.work.title}
                poster_path={result.work.poster_path}
                static
              />
            </div>
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm">{result.work.title}</p>
              <p class="text-base-content/50 font-mono text-[0.65rem]">{meta(result)}</p>
            </div>
            <.link
              :if={result.imported}
              navigate={work_path(result.work)}
              class="btn btn-ghost btn-xs"
            >
              {gettext("Ouvrir")}
            </.link>
            <button
              :if={not result.imported}
              type="button"
              phx-click="import"
              phx-value-kind={result.work.kind}
              phx-value-tmdb-id={result.work.tmdb_id}
              class="btn btn-primary btn-xs"
            >
              {gettext("Importer")}
            </button>
          </li>
        </ul>
      </section>

      <section :if={@members != []} class="pb-8">
        <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
          {gettext("Membres")}
        </h2>
        <ul class="divide-base-300 border-base-300 mt-2 divide-y border-t border-b">
          <li :for={member <- @members} class="py-3">
            <.user_chip user={member} navigate={~p"/u/#{member.username}"} />
          </li>
        </ul>
      </section>

      <p
        :if={@term != "" and String.length(@term) >= 3 and @works == [] and @members == []}
        class="text-base-content/50 py-10 text-sm"
      >
        {gettext("Aucun resultat pour « %{terme} ».", terme: @term)}
      </p>
    </Layouts.app>
    """
  end

  # Le libelle dit franchement qu'une oeuvre vient de TMDB : faire croire a
  # une fiche qui n'existe pas serait pire que de l'annoncer.
  defp meta(%{imported: false, work: attrs}) do
    [year_of(attrs), gettext("pas encore dans Smovie")]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp meta(%{work: work}) do
    [year_of(work), kind_label(work.kind)] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")
  end

  defp year_of(%{release_date: %Date{year: year}}), do: Integer.to_string(year)
  defp year_of(_work), do: nil

  defp kind_label(:tv_show), do: gettext("Serie")
  defp kind_label(_kind), do: gettext("Film")

  defp work_path(%Work{kind: :tv_show, slug: slug}), do: ~p"/serie/#{slug}"
  defp work_path(%Work{slug: slug}), do: ~p"/film/#{slug}"
end
