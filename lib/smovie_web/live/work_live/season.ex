defmodule SmovieWeb.WorkLive.Season do
  @moduledoc """
  Episodes d'une saison.

  Les episodes sont importes au premier affichage : un appel TMDB par saison
  les ramene tous d'un coup.
  """
  use SmovieWeb, :live_view

  alias Smovie.Catalog
  alias Smovie.Library

  @impl true
  def mount(%{"slug" => slug, "number" => number}, _session, socket) do
    with %{} = show <- Catalog.get_tv_show_by_slug(slug),
         %{} = season <- Catalog.get_season(show, number) do
      {:ok, socket |> assign_season(show, season) |> assign(page_title: page_title(show, season))}
    else
      _absent -> raise SmovieWeb.WorkLive.NotFound, "#{slug}/saison/#{number}"
    end
  end

  defp page_title(show, season), do: "#{show.title} · #{season.title}"

  defp assign_season(%{assigns: %{current_scope: scope}} = socket, show, season) do
    episodes = Catalog.fetch_episodes(season)

    assign(socket,
      show: show,
      season: season,
      episodes: episodes,
      progress: Library.season_progress(scope, season),
      ratings: Library.ratings_by_work_id(scope, episodes),
      watched: watched_ids(scope, episodes)
    )
  end

  @impl true
  def handle_event("rate_episode", %{"work-id" => work_id, "value" => value}, socket) do
    with_episode(socket, work_id, &Library.toggle_rating(&1, &2, value))
  end

  def handle_event("toggle_watched", %{"work-id" => work_id}, socket) do
    with_episode(socket, work_id, fn scope, episode ->
      if Library.watched?(scope, episode) do
        Library.unmark_watched(scope, episode)
      else
        Library.mark_watched(scope, episode)
      end
    end)
  end

  def handle_event("mark_season_watched", _params, %{assigns: %{current_scope: nil}} = socket) do
    {:noreply, redirect_to_login(socket)}
  end

  def handle_event(
        "mark_season_watched",
        _params,
        %{assigns: %{current_scope: scope, episodes: episodes}} = socket
      ) do
    Enum.each(episodes, &Library.mark_watched(scope, &1))

    {:noreply, reload(socket)}
  end

  defp with_episode(%{assigns: %{current_scope: nil}} = socket, _work_id, _fun) do
    {:noreply, redirect_to_login(socket)}
  end

  defp with_episode(
         %{assigns: %{current_scope: scope, episodes: episodes}} = socket,
         work_id,
         fun
       ) do
    case Enum.find(episodes, &(to_string(&1.id) == work_id)) do
      nil ->
        {:noreply, socket}

      episode ->
        fun.(scope, episode)
        {:noreply, reload(socket)}
    end
  end

  defp redirect_to_login(socket) do
    socket
    |> put_flash(:info, gettext("Connectez-vous pour noter et suivre vos films."))
    |> push_navigate(to: ~p"/users/log-in")
  end

  defp reload(%{assigns: %{show: show, season: season}} = socket) do
    assign_season(socket, show, Catalog.reload_work(season))
  end

  defp watched_ids(nil, _episodes), do: MapSet.new()

  defp watched_ids(scope, episodes) do
    episodes
    |> Enum.filter(&Library.watched?(scope, &1))
    |> MapSet.new(& &1.id)
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
      <nav class="text-base-content/50 flex items-center gap-2 py-2 font-mono text-xs">
        <.link navigate={~p"/serie/#{@show.slug}"} class="hover:text-base-content">
          {@show.title}
        </.link>
        <span>/</span>
        <span>{@season.title}</span>
      </nav>

      <header class="flex flex-wrap items-baseline gap-x-4 gap-y-1 pb-6">
        <h1 class="font-display text-3xl leading-none font-bold tracking-tight md:text-4xl">
          {@season.title}
        </h1>
        <p class="text-base-content/50 font-mono text-xs">
          {ngettext("%{count} episode", "%{count} episodes", @progress.total, count: @progress.total)} · {gettext(
            "%{watched} vus",
            watched: @progress.watched
          )}
        </p>
      </header>

      <ul :if={@episodes != []} class="border-base-300 divide-base-300 divide-y border-t border-b">
        <li :for={episode <- @episodes} class="flex items-center gap-3 py-3">
          <span class="text-base-content/40 w-14 shrink-0 font-mono text-[0.7rem] tabular-nums">
            S{pad(@season.season_number)}E{pad(episode.episode_number)}
          </span>
          <span class="min-w-0 flex-1">
            <span class="block truncate text-sm">{episode.title}</span>
            <span class="text-base-content/40 mt-0.5 block font-mono text-[0.65rem]">
              {episode_meta(episode)}
            </span>
          </span>
          <button
            type="button"
            phx-click="toggle_watched"
            phx-value-work-id={episode.id}
            aria-pressed={to_string(MapSet.member?(@watched, episode.id))}
            aria-label={gettext("Marquer vu")}
            class={[
              "grid size-11 shrink-0 place-items-center rounded-lg",
              MapSet.member?(@watched, episode.id) && "text-smovie",
              !MapSet.member?(@watched, episode.id) &&
                "text-base-content/25 hover:text-base-content/60"
            ]}
          >
            <.icon name="hero-eye" class="size-4" />
          </button>

          <.episode_rating episode={episode} rating={@ratings[episode.id]} />
        </li>
      </ul>

      <button
        :if={@episodes != [] and @progress.watched < @progress.total}
        type="button"
        phx-click="mark_season_watched"
        class="btn btn-ghost btn-sm mt-4"
      >
        {gettext("Marquer toute la saison comme vue")}
      </button>

      <p :if={@episodes == []} class="text-base-content/50 py-10 text-sm">
        {gettext("Les episodes de cette saison ne sont pas encore disponibles.")}
      </p>
    </Layouts.app>
    """
  end

  # Selecteur de note d'un episode : dix zones de contact superposees aux
  # etoiles, comme sur une fiche. Au doigt, dix petits boutons cote a cote
  # seraient intouchables, et une liste d'episodes en aligne vingt.
  attr :episode, :map, required: true
  attr :rating, :map, default: nil

  defp episode_rating(assigns) do
    ~H"""
    <div class="relative shrink-0 py-1">
      <.rating_stars value={(@rating && @rating.value) || 0} />
      <div class="absolute inset-x-0 -inset-y-1.5 grid grid-cols-10">
        <button
          :for={half <- 1..10}
          type="button"
          phx-click="rate_episode"
          phx-value-work-id={@episode.id}
          phx-value-value={half}
          class="min-h-11 min-w-2 cursor-pointer"
          aria-label={gettext("%{stars} sur 5", stars: format_stars(half))}
          aria-pressed={to_string(@rating && @rating.value == half)}
        ></button>
      </div>
    </div>
    """
  end

  defp pad(number), do: number |> to_string() |> String.pad_leading(2, "0")

  defp episode_meta(episode) do
    [runtime(episode), air_date(episode)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp runtime(%{runtime: nil}), do: nil
  defp runtime(%{runtime: minutes}), do: gettext("%{count} min", count: minutes)

  defp air_date(%{release_date: nil}), do: nil
  defp air_date(%{release_date: date}), do: Calendar.strftime(date, "%d/%m/%Y")
end
