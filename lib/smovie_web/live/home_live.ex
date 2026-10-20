defmodule SmovieWeb.HomeLive do
  @moduledoc """
  Page d'accueil.

  Les blocs sociaux disparaissent purement et simplement pour un visiteur, au
  lieu d'afficher des rangees vides : une page qui montre six emplacements
  vides donne l'impression d'une application en panne, pas d'une application
  qu'on n'a pas encore rejointe.
  """
  use SmovieWeb, :live_view

  alias Smovie.Catalog
  alias Smovie.Catalog.Work
  alias Smovie.Reviews
  alias Smovie.Social
  alias Smovie.Trending

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    {:ok,
     socket
     |> assign(page_title: "Smovie")
     |> assign(headline: Trending.headline())
     |> assign(new_releases: Catalog.list_recent_releases(:movie, limit: 20))
     |> assign(trending_movies: Trending.list(kind: :movie, limit: 20))
     |> assign(trending_shows: Trending.list(kind: :tv_show, limit: 20))
     |> assign(from_following: Trending.popular_with_following(scope, limit: 20))
     |> assign(featured_reviews: Reviews.list_popular(limit: 4))
     |> assign(feed: Social.list_feed(scope, limit: 8))}
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
      full_bleed
    >
      <.hero :if={@headline} work={@headline} />
      <.welcome :if={is_nil(@headline)} />

      <.carousel :if={@new_releases != []} title={gettext("Nouveautes")} more_path={~p"/recherche"}>
        <.poster
          :for={work <- @new_releases}
          title={work.title}
          poster_path={work.poster_path}
          rating={half_stars(work)}
          navigate={work_path(work)}
        />
      </.carousel>

      <.carousel :if={@trending_movies != []} title={gettext("En tendance cette semaine")}>
        <.poster
          :for={{work, index} <- Enum.with_index(@trending_movies, 1)}
          title={work.title}
          poster_path={work.poster_path}
          rating={half_stars(work)}
          rank={index}
          navigate={work_path(work)}
        />
      </.carousel>

      <.carousel :if={@from_following != []} title={gettext("Populaire chez vos abonnements")}>
        <.poster
          :for={work <- @from_following}
          title={work.title}
          poster_path={work.poster_path}
          rating={half_stars(work)}
          navigate={work_path(work)}
        />
      </.carousel>

      <.carousel :if={@trending_shows != []} title={gettext("Series du moment")}>
        <.poster
          :for={work <- @trending_shows}
          title={work.title}
          poster_path={work.poster_path}
          rating={half_stars(work)}
          size={:large}
          navigate={work_path(work)}
        />
      </.carousel>

      <section :if={@featured_reviews != []} class="mt-7 md:mt-9">
        <div class={[Layouts.container_class(), "flex items-baseline gap-3 pb-2.5"]}>
          <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
            {gettext("Reviews a la une")}
          </h2>
          <.link
            navigate={~p"/reviews"}
            class="text-base-content/50 hover:text-base-content ml-auto text-xs"
          >
            {gettext("Tout voir")}
          </.link>
        </div>
        <div class={[Layouts.container_class(), "grid gap-4 md:grid-cols-2 xl:grid-cols-4"]}>
          <.review_card
            :for={review <- @featured_reviews}
            review={review}
            show_work
            navigate={~p"/review/#{review.id}"}
          />
        </div>
      </section>

      <section :if={@feed != []} class="mt-7 md:mt-9">
        <div class={[Layouts.container_class(), "flex items-baseline gap-3 pb-1"]}>
          <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
            {gettext("Activite de vos abonnements")}
          </h2>
        </div>
        <div class={[Layouts.container_class(), "divide-base-300 max-w-2xl divide-y"]}>
          <.activity_item :for={activity <- @feed} activity={activity} />
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :work, :map, required: true

  defp hero(assigns) do
    ~H"""
    <section class="relative flex min-h-[22rem] flex-col justify-end md:min-h-[26rem]">
      <div
        :if={@work.backdrop_path}
        class="absolute inset-0 -z-10 bg-cover bg-center"
        style={"background-image: url('#{poster_url(@work.backdrop_path, 1280)}')"}
      >
      </div>
      <div class="from-base-100 via-base-100/80 absolute inset-0 -z-10 bg-gradient-to-t to-transparent">
      </div>

      <div class={[Layouts.container_class(), "pb-7"]}>
        <span class="bg-heat/15 text-heat inline-flex rounded-full px-2.5 py-1 font-mono text-[0.6rem] tracking-[0.1em] uppercase">
          {gettext("Tendance n°1")}
        </span>
        <h1 class="font-display mt-3 max-w-[16ch] text-4xl leading-none font-extrabold tracking-tight md:text-6xl">
          {@work.title}
        </h1>
        <p class="text-base-content/60 mt-2 font-mono text-xs">{hero_meta(@work)}</p>
        <div class="mt-4 flex flex-wrap items-center gap-3">
          <.link navigate={work_path(@work)} class="btn btn-primary btn-sm">
            {gettext("Voir la fiche")}
          </.link>
          <.rating_stars :if={half_stars(@work)} value={half_stars(@work)} size={:large} />
        </div>
      </div>
    </section>
    """
  end

  # Tant qu'aucune tendance n'existe, mieux vaut dire ce qu'est Smovie que
  # d'afficher une rangee vide la ou devrait se trouver un film.
  defp welcome(assigns) do
    ~H"""
    <section class={[Layouts.container_class(), "flex max-w-3xl flex-col gap-4 py-12 md:py-20"]}>
      <h1 class="font-display text-5xl leading-none font-extrabold tracking-tight md:text-6xl">
        S<span class="text-smovie">movie</span>
      </h1>
      <p class="text-base-content/70">
        {gettext(
          "Films et series, notes en demi-etoiles jusqu'a l'episode, reviews, watchlist et messagerie."
        )}
      </p>
      <p class="text-base-content/40 font-mono text-xs">
        {gettext("Le catalogue se remplit : revenez dans un moment.")}
      </p>
    </section>
    """
  end

  defp hero_meta(work) do
    [Work.year(work), work.tagline]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(" · ")
  end

  defp half_stars(work), do: Work.smovie_half_stars(work, Catalog.min_votes())

  defp work_path(%Work{kind: :tv_show, slug: slug}), do: ~p"/serie/#{slug}"
  defp work_path(%Work{slug: slug}), do: ~p"/film/#{slug}"
end
