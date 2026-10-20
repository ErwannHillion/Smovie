defmodule SmovieWeb.ReviewComponents do
  @moduledoc """
  Composants d'affichage des reviews.
  """
  use Phoenix.Component
  use Gettext, backend: SmovieWeb.Gettext

  import SmovieWeb.UserComponents
  import SmovieWeb.WorkComponents

  alias Smovie.Reviews.Review

  @doc """
  Carte de review.

  Les spoilers sont floutes et non masques : l'espace reste occupe, donc la
  page ne saute pas quand on les revele.
  """
  attr :review, :map, required: true
  attr :show_work, :boolean, default: false
  attr :full, :boolean, default: false
  attr :revealed, :boolean, default: false
  attr :navigate, :string, default: nil
  attr :class, :string, default: nil
  slot :actions

  def review_card(assigns) do
    ~H"""
    <article class={["bg-base-200 border-base-300 rounded-xl border p-4", @class]}>
      <.link
        :if={@show_work}
        navigate={work_path(@review.work)}
        class="border-base-300 mb-3 flex items-center gap-3 border-b pb-3"
      >
        <div class="w-10 shrink-0">
          <.poster title={@review.work.title} poster_path={@review.work.poster_path} static />
        </div>
        <div class="min-w-0">
          <p class="truncate text-sm font-medium">{@review.work.title}</p>
          <p class="text-base-content/50 font-mono text-[0.65rem]">{work_year(@review.work)}</p>
        </div>
      </.link>

      <header class="flex items-center gap-3">
        <.user_chip user={@review.user} navigate={"/u/#{@review.user.username}"} class="flex-1" />
        <.rating_stars :if={@review.rating_value} value={@review.rating_value} />
      </header>

      <div class="relative mt-3">
        <p class={[
          "text-base-content/85 text-sm leading-relaxed whitespace-pre-line",
          @review.contains_spoilers and not @revealed and "blur-[5px] select-none"
        ]}>
          {if @full, do: @review.body, else: Review.excerpt(@review)}
        </p>
      </div>

      <p
        :if={@review.contains_spoilers and not @revealed}
        class="text-press mt-2 flex items-center gap-1.5 font-mono text-[0.65rem] tracking-[0.08em] uppercase"
      >
        {gettext("Contient des spoilers")}
      </p>

      <footer class="text-base-content/50 mt-3 flex items-center gap-4 font-mono text-[0.7rem]">
        <span>{published_label(@review)}</span>
        <.link :if={@navigate} navigate={@navigate} class="hover:text-base-content ml-auto">
          {gettext("Lire")}
        </.link>
        {render_slot(@actions)}
      </footer>
    </article>
    """
  end

  defp work_path(%{kind: :tv_show, slug: slug}), do: "/serie/#{slug}"
  defp work_path(%{slug: slug}), do: "/film/#{slug}"

  defp work_year(%{release_date: %Date{year: year}}), do: year
  defp work_year(_work), do: nil

  defp published_label(%{published_at: published_at}) do
    Calendar.strftime(published_at, "%d/%m/%Y")
  end
end
