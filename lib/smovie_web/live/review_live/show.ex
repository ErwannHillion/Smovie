defmodule SmovieWeb.ReviewLive.Show do
  @moduledoc """
  Une review en entier.
  """
  use SmovieWeb, :live_view

  alias Smovie.Reviews

  @impl true
  def mount(%{"id" => id}, _session, %{assigns: %{current_scope: scope}} = socket) do
    review = Reviews.get_review(id)

    # Une review invisible se comporte comme une review absente : repondre
    # « existe mais vous n'y avez pas droit » revelerait deja quelque chose.
    if review && Reviews.visible?(scope, review) do
      {:ok, assign(socket, review: review, revealed: false, page_title: page_title(review))}
    else
      raise SmovieWeb.ReviewLive.NotFound, id
    end
  end

  defp page_title(review), do: "#{review.user.display_name} · #{review.work.title}"

  @impl true
  def handle_event("reveal", _params, socket), do: {:noreply, assign(socket, revealed: true)}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      current_path={@current_path}
    >
      <div class="max-w-2xl py-4">
        <.review_card review={@review} show_work full revealed={@revealed} />

        <button
          :if={@review.contains_spoilers and not @revealed}
          type="button"
          phx-click="reveal"
          class="btn btn-ghost btn-sm mt-3"
        >
          {gettext("Afficher les spoilers")}
        </button>
      </div>
    </Layouts.app>
    """
  end
end
