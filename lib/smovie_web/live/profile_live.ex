defmodule SmovieWeb.ProfileLive do
  @moduledoc """
  Profil public d'un membre.

  SMOVIE-028 y ajoutera les onglets (films vus, series, reviews, reseau,
  stats) et SMOVIE-029 les statistiques. L'en-tete est pose des maintenant
  parce qu'il donne au username son adresse publique.
  """
  use SmovieWeb, :live_view

  alias Smovie.Accounts
  alias Smovie.Library
  alias Smovie.Reviews
  alias Smovie.Social

  @tabs ~w(apercu films series reviews)

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        raise SmovieWeb.ProfileLive.NotFound, username

      user ->
        {:ok, socket |> assign_profile(user) |> assign(page_title: user.display_name)}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> assign(tab: tab_from(params)) |> assign_tab_content()}
  end

  # L'onglet vient de l'URL : une valeur inconnue retombe sur le premier.
  defp tab_from(%{"onglet" => tab}) when tab in @tabs, do: tab
  defp tab_from(_params), do: "apercu"

  defp assign_tab_content(%{assigns: %{visible: false}} = socket) do
    assign(socket, films: [], series: [], reviews: [], activity: [], stats: nil)
  end

  defp assign_tab_content(%{assigns: %{current_scope: scope, user: user, tab: tab}} = socket) do
    assign(socket,
      films:
        if(tab in ["apercu", "films"],
          do: Library.list_watched_works(user, kind: :movie),
          else: []
        ),
      series: if(tab == "series", do: Library.list_watched_works(user, kind: :tv_show), else: []),
      reviews: if(tab == "reviews", do: Reviews.list_by_user(scope, user), else: []),
      activity: if(tab == "apercu", do: Social.list_user_activity(user, limit: 10), else: []),
      stats: if(tab == "apercu", do: profile_stats(user), else: nil)
    )
  end

  defp profile_stats(user) do
    %{
      films: length(Library.list_watched_works(user, kind: :movie, limit: 1000)),
      ratings: Library.rating_count(user),
      reviews: Reviews.count_by_user(user),
      hours: div(Library.watched_minutes(user), 60)
    }
  end

  defp assign_profile(%{assigns: %{current_scope: scope}} = socket, user) do
    assign(socket,
      user: user,
      visible: Accounts.visible?(scope, user, :profile),
      following?: Social.following?(scope, user)
    )
  end

  @impl true
  def handle_event("toggle_follow", _params, %{assigns: %{current_scope: nil}} = socket) do
    {:noreply,
     socket
     |> put_flash(:info, gettext("Connectez-vous pour suivre des membres."))
     |> push_navigate(to: ~p"/users/log-in")}
  end

  def handle_event(
        "toggle_follow",
        _params,
        %{assigns: %{current_scope: scope, user: user}} = socket
      ) do
    Social.toggle_follow(scope, user)

    {:noreply, assign_profile(socket, Accounts.reload_user(user))}
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
      <header class="flex flex-col gap-4 py-6 md:flex-row md:items-center md:gap-6 md:py-10">
        <.avatar user={@user} size={:large} />
        <div class="min-w-0">
          <h1 class="font-display text-3xl font-bold leading-none tracking-tight md:text-4xl">
            {@user.display_name}
          </h1>
          <p class="text-base-content/50 mt-1.5 font-mono text-xs">
            @{@user.username}<span :if={@visible and @user.location}> · {@user.location}</span>
          </p>
          <p class="text-base-content/70 mt-2 flex gap-4 font-mono text-xs">
            <.link navigate={~p"/u/#{@user.username}/abonnements"} class="hover:text-base-content">
              <b class="text-base-content">{@user.following_count}</b> {gettext("abonnements")}
            </.link>
            <.link navigate={~p"/u/#{@user.username}/abonnes"} class="hover:text-base-content">
              <b class="text-base-content">{@user.followers_count}</b> {gettext("abonnes")}
            </.link>
          </p>
          <p
            :if={@visible and @user.bio}
            class="text-base-content/80 mt-3 max-w-prose text-sm leading-relaxed"
          >
            {@user.bio}
          </p>
        </div>
        <div class="flex items-center gap-2 md:ml-auto">
          <.link
            :if={own_profile?(@current_scope, @user)}
            navigate={~p"/users/settings"}
            class="btn btn-ghost btn-sm"
          >
            {gettext("Modifier mon profil")}
          </.link>
          <button
            :if={not own_profile?(@current_scope, @user)}
            type="button"
            phx-click="toggle_follow"
            aria-pressed={to_string(@following?)}
            class={["btn btn-sm", if(@following?, do: "btn-ghost", else: "btn-primary")]}
          >
            {if @following?, do: gettext("Abonne"), else: gettext("Suivre")}
          </button>
        </div>
      </header>

      <p
        :if={not @visible}
        class="border-base-300 text-base-content/60 flex items-center gap-2 border-t pt-6 text-sm"
      >
        <.icon name="hero-lock-closed" class="size-4" />
        {gettext("Ce profil est prive.")}
      </p>

      <div :if={@visible}>
        <div class="border-base-300 flex gap-1 overflow-x-auto border-b">
          <.link
            :for={{tab, label} <- tabs()}
            patch={~p"/u/#{@user.username}?onglet=#{tab}"}
            aria-current={to_string(@tab == tab)}
            class={[
              "min-h-11 shrink-0 px-3 py-2.5 text-sm",
              @tab == tab && "border-smovie text-base-content border-b-2",
              @tab != tab && "text-base-content/50 hover:text-base-content"
            ]}
          >
            {label}
          </.link>
        </div>

        <div :if={@tab == "apercu"} class="py-6">
          <div class="bg-base-300 grid grid-cols-4 gap-px overflow-hidden rounded-xl md:max-w-lg">
            <.stat value={@stats.films} label={gettext("Films")} />
            <.stat value={@stats.ratings} label={gettext("Notes")} />
            <.stat value={@stats.reviews} label={gettext("Reviews")} />
            <.stat value={@stats.hours} label={gettext("Heures")} />
          </div>

          <section :if={@films != []} class="mt-7">
            <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
              {gettext("Derniers films vus")}
            </h2>
            <.poster_grid class="mt-3">
              <.poster
                :for={work <- Enum.take(@films, 8)}
                title={work.title}
                poster_path={work.poster_path}
                navigate={~p"/film/#{work.slug}"}
                class="w-full"
              />
            </.poster_grid>
          </section>

          <section :if={@activity != []} class="mt-7 max-w-2xl">
            <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
              {gettext("Activite recente")}
            </h2>
            <div class="divide-base-300 mt-1 divide-y">
              <.activity_item :for={activity <- @activity} activity={activity} />
            </div>
          </section>
        </div>

        <div :if={@tab == "films"} class="py-6">
          <.poster_grid :if={@films != []}>
            <.poster
              :for={work <- @films}
              title={work.title}
              poster_path={work.poster_path}
              navigate={~p"/film/#{work.slug}"}
              class="w-full"
            />
          </.poster_grid>
          <p :if={@films == []} class="text-base-content/50 text-sm">
            {gettext("Aucun film vu pour l'instant.")}
          </p>
        </div>

        <div :if={@tab == "series"} class="py-6">
          <.poster_grid :if={@series != []}>
            <.poster
              :for={work <- @series}
              title={work.title}
              poster_path={work.poster_path}
              navigate={~p"/serie/#{work.slug}"}
              class="w-full"
            />
          </.poster_grid>
          <p :if={@series == []} class="text-base-content/50 text-sm">
            {gettext("Aucune serie suivie pour l'instant.")}
          </p>
        </div>

        <div :if={@tab == "reviews"} class="grid gap-4 py-6 md:grid-cols-2 xl:grid-cols-3">
          <.review_card
            :for={review <- @reviews}
            review={review}
            show_work
            navigate={~p"/review/#{review.id}"}
          />
          <p :if={@reviews == []} class="text-base-content/50 text-sm">
            {gettext("Aucune review pour l'instant.")}
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :value, :integer, required: true
  attr :label, :string, required: true

  defp stat(assigns) do
    ~H"""
    <div class="bg-base-200 px-2 py-3 text-center">
      <p class="font-mono text-lg font-semibold tabular-nums">{@value}</p>
      <p class="text-base-content/50 font-mono text-[0.55rem] tracking-[0.1em] uppercase">
        {@label}
      </p>
    </div>
    """
  end

  defp tabs do
    [
      {"apercu", gettext("Apercu")},
      {"films", gettext("Films")},
      {"series", gettext("Series")},
      {"reviews", gettext("Reviews")}
    ]
  end

  defp own_profile?(%{user: %{id: id}}, %{id: id}), do: true
  defp own_profile?(_scope, _user), do: false
end
