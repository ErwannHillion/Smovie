defmodule SmovieWeb.WorkLive.Show do
  @moduledoc """
  Fiche d'un film ou d'une serie.

  La page est servie meme si l'oeuvre n'est pas a jour : ce qu'on a s'affiche
  immediatement, et le rafraichissement part en tache de fond. Attendre TMDB
  rendrait chaque fiche tributaire de la latence d'un tiers.
  """
  use SmovieWeb, :live_view

  alias Smovie.Accounts.Visibility
  alias Smovie.Catalog
  alias Smovie.Catalog.Work
  alias Smovie.Library
  alias Smovie.Repo
  alias Smovie.Reviews
  alias Smovie.Reviews.Review
  alias SmovieWeb.Layouts

  @impl true
  def mount(%{"slug" => slug}, _session, %{assigns: %{live_action: action}} = socket) do
    case Catalog.fetch_work_by_slug(kind_for(action), slug) do
      {:error, :not_found} ->
        raise SmovieWeb.WorkLive.NotFound, slug

      {:ok, work} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Smovie.PubSub, Library.rating_topic(work))
        end

        {:ok, socket |> assign_work(work) |> assign(page_title: work.title)}
    end
  end

  defp kind_for(:movie), do: :movie
  defp kind_for(:tv_show), do: :tv_show

  defp assign_work(%{assigns: %{current_scope: scope}} = socket, work) do
    seasons = if work.kind == :tv_show, do: Catalog.fetch_seasons(work), else: []

    assign(socket,
      seasons: seasons,
      progress: Library.season_progress_by_id(scope, seasons),
      work: work,
      genres: Catalog.list_work_genres(work),
      directors: Catalog.list_directors(work),
      cast: Catalog.list_cast(work),
      press: Catalog.press_rating(work),
      my_rating: Library.get_rating(scope, work),
      my_review: Reviews.get_user_review(scope, work),
      popular_reviews: Reviews.list_popular_for_work(work),
      watched?: Library.watched?(scope, work),
      in_watchlist?: Library.in_watchlist?(scope, work),
      liked?: Library.liked?(scope, work)
    )
    |> assign_new(:editing_review, fn -> false end)
    |> then(&assign(&1, review_form: review_form(&1)))
  end

  defp review_form(%{assigns: %{my_review: review}}) do
    to_form(Reviews.change_review(review || %Review{}))
  end

  @impl true
  def handle_event("edit_review", _params, %{assigns: %{current_scope: nil}} = socket) do
    {:noreply, redirect_to_login(socket)}
  end

  def handle_event("edit_review", _params, socket) do
    {:noreply, assign(socket, editing_review: true)}
  end

  def handle_event("cancel_review", _params, socket) do
    {:noreply, assign(socket, editing_review: false)}
  end

  def handle_event(
        "save_review",
        %{"review" => params},
        %{assigns: %{current_scope: scope, work: work}} = socket
      ) do
    case Reviews.publish(scope, work, params) do
      {:ok, _review} ->
        {:noreply,
         socket
         |> assign(editing_review: false)
         |> assign_work(Repo.reload!(work))
         |> put_flash(:info, gettext("Review publiee."))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, review_form: to_form(changeset))}
    end
  end

  def handle_event(
        "delete_review",
        _params,
        %{assigns: %{current_scope: scope, work: work}} = socket
      ) do
    case Reviews.get_user_review(scope, work) do
      nil ->
        {:noreply, socket}

      review ->
        Reviews.delete(scope, review)
        {:noreply, assign_work(socket, Repo.reload!(work))}
    end
  end

  def handle_event("rate", %{"value" => value}, socket) do
    with_scope(socket, &Library.toggle_rating(&1, &2, value))
  end

  def handle_event("toggle_watched", _params, socket) do
    with_scope(socket, fn scope, work ->
      if Library.watched?(scope, work) do
        Library.unmark_watched(scope, work)
      else
        Library.mark_watched(scope, work)
      end
    end)
  end

  def handle_event("toggle_watchlist", _params, socket) do
    with_scope(socket, &Library.toggle_watchlist/2)
  end

  def handle_event("toggle_like", _params, socket) do
    with_scope(socket, &Library.toggle_like/2)
  end

  # Un visiteur non connecte est renvoye vers la connexion plutot que de voir
  # son geste ignore sans explication.
  defp with_scope(%{assigns: %{current_scope: nil}} = socket, _fun) do
    {:noreply, redirect_to_login(socket)}
  end

  defp with_scope(%{assigns: %{current_scope: scope, work: work}} = socket, fun) do
    fun.(scope, work)

    {:noreply, assign_work(socket, Repo.reload!(work))}
  end

  defp redirect_to_login(socket) do
    socket
    |> put_flash(:info, gettext("Connectez-vous pour noter et suivre vos films."))
    |> push_navigate(to: ~p"/users/log-in")
  end

  @impl true
  def handle_info(
        {:rating_updated, %Work{id: id}},
        %{assigns: %{work: %Work{id: id} = work}} = socket
      ) do
    {:noreply, assign_work(socket, Repo.reload!(work))}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      current_path={@current_path}
      full_bleed
    >
      <.work_header work={@work} directors={@directors} genres={@genres} />

      <div class={[Layouts.container_class(), "grid gap-8 pb-10 lg:grid-cols-[minmax(0,1fr)_22rem]"]}>
        <div class="order-2 flex min-w-0 flex-col gap-8 lg:order-1">
          <p :if={@work.overview} class="text-base-content/80 max-w-prose leading-relaxed">
            {@work.overview}
          </p>

          <section>
            <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
              {gettext("Votre review")}
            </h2>

            <.form
              :if={@editing_review}
              for={@review_form}
              id="review_form"
              phx-submit="save_review"
              class="mt-3"
            >
              <.input
                field={@review_form[:body]}
                type="textarea"
                label={gettext("Ce que vous en avez pense")}
                rows="6"
                required
              />
              <div class="flex flex-wrap items-center gap-4">
                <.input
                  field={@review_form[:contains_spoilers]}
                  type="checkbox"
                  label={gettext("Contient des spoilers")}
                />
                <.input
                  field={@review_form[:visibility]}
                  type="select"
                  options={Visibility.options()}
                  label={gettext("Visible par")}
                />
              </div>
              <div class="flex gap-2">
                <.button variant="primary" phx-disable-with={gettext("Publication...")}>
                  {gettext("Publier")}
                </.button>
                <button type="button" phx-click="cancel_review" class="btn btn-ghost">
                  {gettext("Annuler")}
                </button>
              </div>
            </.form>

            <div :if={not @editing_review} class="mt-3">
              <.review_card :if={@my_review} review={@my_review} full revealed>
                <:actions>
                  <button type="button" phx-click="edit_review" class="hover:text-base-content">
                    {gettext("Modifier")}
                  </button>
                  <button
                    type="button"
                    phx-click="delete_review"
                    data-confirm={gettext("Supprimer cette review ?")}
                    class="hover:text-heat"
                  >
                    {gettext("Supprimer")}
                  </button>
                </:actions>
              </.review_card>

              <button
                :if={is_nil(@my_review)}
                type="button"
                phx-click="edit_review"
                class="btn btn-ghost btn-sm"
              >
                {gettext("Ecrire une review")}
              </button>
            </div>
          </section>

          <section :if={@popular_reviews != []}>
            <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
              {gettext("Reviews populaires")}
            </h2>
            <div class="mt-3 flex flex-col gap-3">
              <.review_card
                :for={review <- @popular_reviews}
                review={review}
                navigate={~p"/review/#{review.id}"}
              />
            </div>
          </section>

          <section :if={@seasons != []}>
            <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
              {gettext("Saisons")}
            </h2>
            <ul class="border-base-300 mt-3 divide-base-300 divide-y border-t border-b">
              <li :for={season <- @seasons}>
                <.link
                  navigate={~p"/serie/#{@work.slug}/saison/#{season.season_number}"}
                  class="hover:bg-base-200 flex items-center gap-4 px-1 py-3.5"
                >
                  <span class="font-display text-base-content/50 w-9 text-xl leading-none font-bold">
                    S{season.season_number}
                  </span>
                  <span class="min-w-0 flex-1">
                    <span class="block text-sm font-medium">{season.title}</span>
                    <span class="text-base-content/50 mt-0.5 block font-mono text-[0.65rem]">
                      {season_summary(@progress[season.id])}
                    </span>
                    <span class="bg-base-300 mt-1.5 block h-1 overflow-hidden rounded-full">
                      <span
                        class="bg-smovie block h-full"
                        style={"width: #{progress_percent(@progress[season.id])}%"}
                      ></span>
                    </span>
                  </span>
                  <.icon name="hero-chevron-right" class="text-base-content/30 size-4" />
                </.link>
              </li>
            </ul>
          </section>

          <section :if={@cast != []}>
            <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
              {gettext("Distribution")}
            </h2>
            <ul class="snap-row mt-3 flex gap-3 overflow-x-auto pb-1">
              <li :for={credit <- @cast} class="w-20 shrink-0 text-center">
                <div class="bg-base-300 mx-auto size-20 overflow-hidden rounded-full">
                  <img
                    :if={credit.person.profile_path}
                    src={poster_url(credit.person.profile_path, 185)}
                    alt={credit.person.name}
                    loading="lazy"
                    class="h-full w-full object-cover"
                  />
                </div>
                <p class="mt-1.5 text-xs leading-tight">{credit.person.name}</p>
                <p :if={credit.character} class="text-base-content/50 text-[0.65rem] leading-tight">
                  {credit.character}
                </p>
              </li>
            </ul>
          </section>
        </div>

        <aside class="order-1 flex flex-col gap-3 lg:order-2">
          <.score_block
            smovie_average={smovie_average(@work)}
            smovie_count={@work.smovie_rating_count}
            press_score={press_score(@press)}
            press_source={press_source(@press)}
            tmdb_score={Work.tmdb_out_of_ten(@work)}
          />

          <.rating_input value={@my_rating && @my_rating.value} event="rate" />

          <div class="bg-base-300 grid grid-cols-3 gap-px overflow-hidden rounded-xl">
            <.work_action
              event="toggle_watched"
              active={@watched?}
              icon="hero-eye"
              label={if @watched?, do: gettext("Vu"), else: gettext("Marquer vu")}
            />
            <.work_action
              event="toggle_watchlist"
              active={@in_watchlist?}
              icon="hero-bookmark"
              label={if @in_watchlist?, do: gettext("Dans la liste"), else: gettext("Watchlist")}
            />
            <.work_action
              event="toggle_like"
              active={@liked?}
              icon="hero-heart"
              tone="heat"
              label={gettext("J'aime")}
            />
          </div>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  attr :work, :map, required: true
  attr :directors, :list, required: true
  attr :genres, :list, required: true

  defp work_header(assigns) do
    ~H"""
    <header class="relative">
      <div
        :if={@work.backdrop_path}
        class="absolute inset-0 -z-10 bg-cover bg-center opacity-40"
        style={"background-image: url('#{poster_url(@work.backdrop_path, 780)}')"}
      >
      </div>
      <div class="from-base-100 via-base-100/70 absolute inset-0 -z-10 bg-gradient-to-t to-transparent">
      </div>

      <div class={[Layouts.container_class(), "flex gap-5 pt-10 pb-8 md:gap-7 md:pt-16"]}>
        <div class="w-24 shrink-0 md:w-40">
          <.poster title={@work.title} poster_path={@work.poster_path} eager class="w-full" />
        </div>
        <div class="min-w-0 self-end">
          <h1 class="font-display text-3xl leading-none font-bold tracking-tight md:text-5xl">
            {@work.title}
          </h1>
          <p class="text-base-content/60 mt-2 font-mono text-xs">
            {[Work.year(@work), runtime_label(@work)] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")}
          </p>
          <p :if={@directors != []} class="text-base-content/70 mt-1.5 text-sm">
            {gettext("de")}
            <span class="text-base-content font-medium">
              {Enum.map_join(@directors, ", ", & &1.name)}
            </span>
          </p>
          <div :if={@genres != []} class="mt-3 flex flex-wrap gap-1.5">
            <span
              :for={genre <- @genres}
              class="bg-base-200 text-base-content/70 rounded-full px-2.5 py-1 text-xs"
            >
              {genre.name}
            </span>
          </div>
        </div>
      </div>
    </header>
    """
  end

  attr :event, :string, required: true
  attr :active, :boolean, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :tone, :string, default: "smovie"

  defp work_action(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@event}
      aria-pressed={to_string(@active)}
      class={[
        "bg-base-200 flex min-h-14 flex-col items-center justify-center gap-1 px-2 py-2.5",
        "font-mono text-[0.6rem] tracking-[0.05em] uppercase",
        action_tone(@active, @tone)
      ]}
    >
      <.icon name={@icon} class="size-5" />
      {@label}
    </button>
    """
  end

  defp action_tone(false, _tone), do: "text-base-content/50"
  defp action_tone(true, "heat"), do: "text-heat"
  defp action_tone(true, _tone), do: "text-smovie"

  defp runtime_label(%Work{runtime: nil}), do: nil
  defp runtime_label(%Work{runtime: minutes}), do: gettext("%{count} min", count: minutes)

  defp smovie_average(%Work{} = work) do
    case Work.smovie_out_of_five(work) do
      nil -> nil
      average -> average
    end
  end

  defp press_score(nil), do: nil
  defp press_score({_source, score}), do: score

  defp press_source(nil), do: nil
  defp press_source({source, _score}), do: source

  # Les deux chiffres ensemble : « 7 vus » seul ne dit rien, et le total seul
  # ne dit pas ou on en est.
  defp season_summary(%{watched: watched, total: total}) do
    ngettext("%{count} episode", "%{count} episodes", total, count: total) <>
      " · " <> gettext("%{watched} vus", watched: watched)
  end

  defp season_summary(_absent), do: ""

  defp progress_percent(%{total: 0}), do: 0
  defp progress_percent(%{watched: watched, total: total}), do: round(watched / total * 100)
  defp progress_percent(_absent), do: 0
end
