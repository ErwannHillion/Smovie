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
      watched: watched_ids(scope, episodes)
    )
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
          <.icon
            :if={MapSet.member?(@watched, episode.id)}
            name="hero-eye"
            class="text-smovie size-4 shrink-0"
          />
        </li>
      </ul>

      <p :if={@episodes == []} class="text-base-content/50 py-10 text-sm">
        {gettext("Les episodes de cette saison ne sont pas encore disponibles.")}
      </p>
    </Layouts.app>
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
