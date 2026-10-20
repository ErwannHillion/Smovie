defmodule SmovieWeb.WorkComponents do
  @moduledoc """
  Composants d'affichage des oeuvres : affiches, grilles, carrousels, notes.

  Ils prennent des attributs primitifs plutot qu'une struct `Work` : ils
  servent aussi a rendre des resultats de recherche TMDB pas encore importes,
  et des cartes de partage en messagerie, qui n'ont pas la meme forme.

  Toutes les tailles partent du mobile. Les classes `md:` et au-dela ne font
  qu'elargir.
  """
  use Phoenix.Component
  use Gettext, backend: SmovieWeb.Gettext

  alias Smovie.Config
  alias SmovieWeb.Layouts

  # Largeurs TMDB utilisees, de la vignette mobile au backdrop desktop.
  @poster_widths [185, 342, 500]

  @doc """
  Affiche d'une oeuvre.

  `rating` est en demi-etoiles (1..10) ou `nil`. `navigate` rend l'affiche
  cliquable ; sans lui, elle est rendue en `<div>`, ce qui permet de l'imbriquer
  dans un parent lui-meme cliquable sans produire de bouton dans un bouton.
  """
  attr :title, :string, required: true
  attr :poster_path, :string, default: nil
  attr :rating, :integer, default: nil
  attr :rank, :integer, default: nil
  attr :subtitle, :string, default: nil
  attr :navigate, :string, default: nil
  attr :size, :atom, default: :default, values: [:small, :default, :large]
  attr :static, :boolean, default: false, doc: "rendu en span, pour un parent deja cliquable"
  attr :eager, :boolean, default: false, doc: "charge l'image sans attendre le defilement"
  attr :class, :string, default: nil

  def poster(assigns) do
    ~H"""
    <.poster_wrapper
      navigate={if @static, do: nil, else: @navigate}
      class={["group block text-left", width(@size), @class]}
    >
      <div class="relative">
        <div class="bg-base-300 ring-base-content/10 aspect-[2/3] overflow-hidden rounded-lg ring-1">
          <img
            :if={@poster_path}
            src={poster_url(@poster_path, 342)}
            srcset={poster_srcset(@poster_path)}
            sizes="(min-width: 768px) 11rem, 33vw"
            alt={@title}
            loading={if @eager, do: "eager", else: "lazy"}
            decoding="async"
            class="h-full w-full object-cover"
          />
          <div
            :if={is_nil(@poster_path)}
            class="text-base-content/40 font-display flex h-full w-full items-end p-2 text-lg font-semibold leading-tight"
          >
            {@title}
          </div>
        </div>
        <span
          :if={@rank}
          class="bg-heat border-base-100 absolute -top-1.5 -left-1.5 grid h-6 w-6 place-items-center rounded-full border-2 font-mono text-xs font-semibold text-[#2a0613]"
        >
          {@rank}
        </span>
      </div>

      <p class="mt-1.5 truncate text-xs leading-tight">{@title}</p>
      <.rating_stars :if={@rating} value={@rating} class="mt-1" />
      <p :if={@subtitle} class="text-base-content/50 mt-1 font-mono text-[0.65rem]">{@subtitle}</p>
    </.poster_wrapper>
    """
  end

  attr :navigate, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp poster_wrapper(%{navigate: nil} = assigns) do
    ~H"<div class={@class}>{render_slot(@inner_block)}</div>"
  end

  defp poster_wrapper(assigns) do
    ~H"""
    <.link navigate={@navigate} class={@class}>{render_slot(@inner_block)}</.link>
    """
  end

  defp width(:small), do: "w-[4.5rem] md:w-24"
  defp width(:default), do: "w-24 md:w-[8.5rem]"
  defp width(:large), do: "w-32 md:w-40"

  @doc """
  Grille d'affiches : trois colonnes sur mobile, jusqu'a huit sur grand ecran.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def poster_grid(assigns) do
    ~H"""
    <div class={[
      "grid grid-cols-3 gap-3 sm:grid-cols-4 md:grid-cols-6 md:gap-4 lg:grid-cols-8",
      "xl:grid-cols-10 2xl:grid-cols-12",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Rangee d'affiches a defilement horizontal, avec arret sur chaque affiche.

  Le defilement est natif : `scroll-snap` suffit, sans JavaScript, et la rangee
  reste utilisable au clavier et a la molette.
  """
  attr :title, :string, required: true
  attr :more_path, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def carousel(assigns) do
    ~H"""
    <section class={["mt-7 md:mt-9", @class]}>
      <div class={[Layouts.container_class(), "flex items-baseline gap-3 pb-2.5"]}>
        <h2 class="text-base-content/70 font-mono text-[0.65rem] font-medium tracking-[0.15em] uppercase">
          {@title}
        </h2>
        <.link
          :if={@more_path}
          navigate={@more_path}
          class="text-base-content/50 hover:text-base-content ml-auto text-xs"
        >
          {gettext("Tout voir")}
        </.link>
      </div>
      <div class={[Layouts.container_class(), "snap-row flex gap-2.5 overflow-x-auto pb-1 md:gap-3.5"]}>
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  @doc """
  Note en etoiles, en lecture seule.

  `value` est le nombre de demi-etoiles, de 1 a 10. Deux rangees superposees
  plutot que dix glyphes : la rangee pleine est tronquee a la largeur voulue,
  ce qui rend les demi-etoiles sans glyphe dedie et sans arrondi visuel.
  """
  attr :value, :integer, required: true
  attr :size, :atom, default: :default, values: [:default, :large]
  attr :class, :string, default: nil

  def rating_stars(assigns) do
    assigns = assign(assigns, :percent, assigns.value / 10 * 100)

    ~H"""
    <span
      class={["relative inline-block leading-none whitespace-nowrap", star_size(@size), @class]}
      title={gettext("%{stars} sur 5", stars: format_stars(@value))}
    >
      <span class="text-base-content/20" aria-hidden="true">★★★★★</span>
      <span
        class="text-smovie absolute inset-0 overflow-hidden"
        style={"width: #{@percent}%"}
        aria-hidden="true"
      >
        ★★★★★
      </span>
      <span class="sr-only">{gettext("%{stars} sur 5", stars: format_stars(@value))}</span>
    </span>
    """
  end

  defp star_size(:default), do: "text-[0.8rem] tracking-[1.5px]"
  defp star_size(:large), do: "text-2xl tracking-[4px]"

  @doc """
  Selecteur de note.

  Dix zones de contact superposees aux etoiles, chacune haute de 44 px : au
  doigt, dix petits boutons cote a cote seraient intouchables. Cliquer la note
  deja posee la retire.
  """
  attr :value, :integer, default: nil
  attr :event, :string, default: "rate"
  attr :target, :any, default: nil
  attr :work_id, :any, default: nil
  attr :class, :string, default: nil

  def rating_input(assigns) do
    ~H"""
    <div class={["bg-base-200 border-base-300 rounded-xl border p-3.5", @class]}>
      <p class="text-base-content/50 font-mono text-[0.6rem] tracking-[0.13em] uppercase">
        {gettext("Votre note")}
      </p>
      <div class="relative mt-1.5 flex items-center gap-3">
        <.rating_stars value={@value || 0} size={:large} />
        <div class="absolute inset-x-0 -inset-y-2 grid grid-cols-10">
          <button
            :for={half <- 1..10}
            type="button"
            phx-click={@event}
            phx-target={@target}
            phx-value-work-id={@work_id}
            phx-value-value={half}
            class="min-h-11 cursor-pointer"
            aria-label={gettext("%{stars} sur 5", stars: format_stars(half))}
            aria-pressed={to_string(@value == half)}
          ></button>
        </div>
        <span class="text-base-content/60 ml-auto font-mono text-xs tabular-nums">
          <%= if @value do %>
            <b class="text-smovie font-semibold">{format_stars(@value)}</b> / 5
          <% else %>
            {gettext("Glissez pour noter")}
          <% end %>
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Bloc des trois notes d'une fiche.

  La note Smovie n'est affichee qu'au-dela du seuil de votes : en dessous, une
  moyenne est plus trompeuse qu'utile, et le nombre brut de notes dit la verite.
  """
  attr :smovie_average, :float, default: nil
  attr :smovie_count, :integer, default: 0
  attr :press_score, :float, default: nil
  attr :press_source, :string, default: nil
  attr :tmdb_score, :float, default: nil
  attr :class, :string, default: nil

  def score_block(assigns) do
    ~H"""
    <div class={[
      "bg-base-300 grid grid-cols-3 gap-px overflow-hidden rounded-xl",
      @class
    ]}>
      <.score
        label={gettext("Smovie")}
        tone="text-smovie"
        value={smovie_value(@smovie_average, @smovie_count)}
      >
        {ngettext("%{count} note", "%{count} notes", @smovie_count, count: @smovie_count)}
      </.score>
      <.score label={@press_source || gettext("Presse")} tone="text-press" value={fmt(@press_score)}>
        {gettext("presse")}
      </.score>
      <.score label={gettext("TMDB")} tone="text-base-content/60" value={fmt(@tmdb_score)}>
        {gettext("public")}
      </.score>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :tone, :string, required: true
  slot :inner_block, required: true

  defp score(assigns) do
    ~H"""
    <div class="bg-base-200 px-2.5 py-3 text-center" data-score={@label}>
      <p class="text-base-content/50 font-mono text-[0.55rem] tracking-[0.12em] uppercase">
        {@label}
      </p>
      <p class={["mt-0.5 font-mono text-xl font-semibold tabular-nums", @tone]}>{@value}</p>
      <p class="text-base-content/40 font-mono text-[0.65rem]">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  defp smovie_value(_average, count) when count < 1, do: "—"

  defp smovie_value(average, count) do
    if count >= Config.trending_min_votes(), do: fmt(average), else: "—"
  end

  defp fmt(nil), do: "—"

  defp fmt(score) when is_float(score) do
    score |> :erlang.float_to_binary(decimals: 1) |> localize_decimal()
  end

  defp fmt(score) when is_integer(score), do: Integer.to_string(score)

  @doc """
  Formate un nombre de demi-etoiles en note sur 5 : 9 donne « 4,5 ».
  """
  def format_stars(half_stars) when is_integer(half_stars) do
    half_stars
    |> Kernel./(2)
    |> :erlang.float_to_binary(decimals: 1)
    |> localize_decimal()
  end

  # La virgule decimale n'est pas une preference : c'est une regle de locale.
  defp localize_decimal(value) do
    case Gettext.get_locale(SmovieWeb.Gettext) do
      "fr" -> String.replace(value, ".", ",")
      _other -> value
    end
  end

  @doc """
  URL d'une affiche TMDB a la largeur demandee.
  """
  def poster_url(nil, _width), do: nil
  def poster_url(path, width), do: "#{Config.tmdb_image_base_url()}/w#{width}#{path}"

  defp poster_srcset(path) do
    Enum.map_join(@poster_widths, ", ", fn width -> "#{poster_url(path, width)} #{width}w" end)
  end
end
