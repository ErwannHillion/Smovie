defmodule SmovieWeb.ActivityComponents do
  @moduledoc """
  Rendu du fil d'activite.
  """
  use Phoenix.Component
  use Gettext, backend: SmovieWeb.Gettext

  import SmovieWeb.UserComponents
  import SmovieWeb.WorkComponents

  @doc """
  Une ligne du fil.

  La phrase est construite par nature d'activite plutot que par concatenation
  de fragments : « a note » et « a aime » ne se declinent pas de la meme
  maniere d'une langue a l'autre, et assembler des morceaux rend la traduction
  impossible.
  """
  attr :activity, :map, required: true
  attr :class, :string, default: nil

  def activity_item(assigns) do
    ~H"""
    <article class={["flex items-center gap-3 py-3", @class]}>
      <.link navigate={"/u/#{@activity.user.username}"}>
        <.avatar user={@activity.user} />
      </.link>

      <div class="min-w-0 flex-1">
        <p class="text-sm leading-tight">{sentence(@activity)}</p>
        <p class="text-base-content/50 mt-1 flex items-center gap-2 font-mono text-[0.65rem]">
          {Calendar.strftime(@activity.inserted_at, "%d/%m/%Y")}
          <.rating_stars :if={@activity.rating_value} value={@activity.rating_value} />
        </p>
      </div>

      <.link :if={@activity.work} navigate={work_path(@activity.work)} class="w-10 shrink-0">
        <.poster title={@activity.work.title} poster_path={@activity.work.poster_path} static />
      </.link>
    </article>
    """
  end

  defp sentence(%{kind: :rated, user: user, work: work}),
    do: gettext("%{member} a note %{work}", member: user.display_name, work: work.title)

  defp sentence(%{kind: :watched, user: user, work: work}),
    do: gettext("%{member} a vu %{work}", member: user.display_name, work: work.title)

  defp sentence(%{kind: :reviewed, user: user, work: work}),
    do:
      gettext("%{member} a publie une review de %{work}",
        member: user.display_name,
        work: work.title
      )

  defp sentence(%{kind: :liked_work, user: user, work: work}),
    do: gettext("%{member} a aime %{work}", member: user.display_name, work: work.title)

  defp sentence(%{kind: :followed, user: user, target_user: target}),
    do:
      gettext("%{member} suit desormais %{other}",
        member: user.display_name,
        other: target.display_name
      )

  defp sentence(_activity), do: ""

  defp work_path(%{kind: :tv_show, slug: slug}), do: "/serie/#{slug}"
  defp work_path(%{kind: :season, slug: slug}), do: "/serie/#{slug}"
  defp work_path(%{slug: slug}), do: "/film/#{slug}"
end
