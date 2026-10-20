defmodule SmovieWeb.ReviewLive.Index do
  @moduledoc """
  Les reviews de la plateforme, en trois onglets.
  """
  use SmovieWeb, :live_view

  alias Smovie.Reviews

  @tabs ~w(populaires abonnements recentes)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Reviews"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = tab_from(params)

    {:noreply, socket |> assign(tab: tab) |> assign_reviews(tab)}
  end

  # L'onglet vient de l'URL : une valeur inconnue retombe sur le premier plutot
  # que de lever.
  defp tab_from(%{"onglet" => tab}) when tab in @tabs, do: tab
  defp tab_from(_params), do: "populaires"

  defp assign_reviews(%{assigns: %{current_scope: scope}} = socket, tab) do
    reviews = list(tab, scope)

    assign(socket, reviews: reviews, liked: Reviews.liked_review_ids(scope, reviews))
  end

  defp list("abonnements", nil), do: []
  defp list("abonnements", scope), do: Reviews.list_from_following(scope)
  defp list("recentes", _scope), do: Reviews.list_recent()
  defp list(_populaires, _scope), do: Reviews.list_popular()

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      current_path={@current_path}
    >
      <h1 class="font-display py-4 text-3xl leading-none font-bold tracking-tight md:text-4xl">
        {gettext("Reviews")}
      </h1>

      <div class="border-base-300 flex gap-1 border-b">
        <.link
          :for={{tab, label} <- tabs()}
          patch={~p"/reviews?onglet=#{tab}"}
          aria-current={to_string(@tab == tab)}
          class={[
            "min-h-11 px-3 py-2.5 text-sm",
            @tab == tab && "border-smovie text-base-content border-b-2",
            @tab != tab && "text-base-content/50 hover:text-base-content"
          ]}
        >
          {label}
        </.link>
      </div>

      <div
        :if={@reviews != []}
        class="mt-5 grid gap-4 md:grid-cols-2 xl:grid-cols-3"
      >
        <.review_card
          :for={review <- @reviews}
          review={review}
          show_work
          navigate={~p"/review/#{review.id}"}
        />
      </div>

      <p :if={@reviews == []} class="text-base-content/50 py-12 text-sm">
        {empty_label(@tab, @current_scope)}
      </p>
    </Layouts.app>
    """
  end

  defp tabs do
    [
      {"populaires", gettext("Populaires")},
      {"abonnements", gettext("De vos abonnements")},
      {"recentes", gettext("Recentes")}
    ]
  end

  defp empty_label("abonnements", nil),
    do: gettext("Connectez-vous pour voir les reviews des comptes que vous suivez.")

  defp empty_label("abonnements", _scope),
    do: gettext("Les comptes que vous suivez n'ont encore rien publie.")

  defp empty_label(_tab, _scope), do: gettext("Aucune review pour l'instant.")
end
