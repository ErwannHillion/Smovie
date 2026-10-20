defmodule SmovieWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use SmovieWeb, :html

  alias Smovie.Config

  # Gouttiere unique de l'application, de 360 px a l'ultra-large.
  #
  # Pas de `max-w-6xl` : sur un ecran de 1920 il laissait deux bandes vides de
  # 380 px de chaque cote, alors qu'une grille d'affiches gagne a etre remplie.
  # Le plafond a 120rem (1920 px) n'existe que pour les ecrans ultra-larges, ou
  # une rangee sans fin deviendrait illisible.
  @container "mx-auto w-full max-w-[120rem] px-4 sm:px-6 lg:px-10 xl:px-14"

  @doc """
  Classes de la gouttiere, partagees par la mise en page et les carrousels.
  """
  def container_class, do: @container

  embed_templates "layouts/*"

  @doc """
  Mise en page applicative.

  Mobile d'abord : barre de navigation **basse** jusqu'a `md:`, barre haute
  au-dela. Sur telephone, le pouce atteint le bas de l'ecran, pas le haut — et
  une barre haute se retrouve sous l'encoche ou la barre d'URL.

  Le contenu reserve la hauteur de la barre basse et l'encoche (`pb-safe`),
  sans quoi la derniere ligne de chaque page serait masquee.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :locale, :string, default: nil
  attr :current_path, :string, default: "/"
  attr :unread_count, :integer, default: 0
  attr :unread_messages, :integer, default: 0
  attr :full_bleed, :boolean, default: false, doc: "colle le contenu aux bords (heros)"
  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :container, @container)

    ~H"""
    <.top_nav
      current_scope={@current_scope}
      locale={@locale}
      current_path={@current_path}
      unread_count={@unread_count}
    />

    <main class={[
      "pb-safe min-h-dvh md:pb-10",
      not @full_bleed && [@container, "py-6"]
    ]}>
      {render_slot(@inner_block)}
    </main>

    <.bottom_nav
      current_scope={@current_scope}
      current_path={@current_path}
      unread_messages={@unread_messages}
    />
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Barre haute, a partir de `md:`.
  """
  attr :current_scope, :map, default: nil
  attr :locale, :string, default: nil
  attr :current_path, :string, default: "/"
  attr :unread_count, :integer, default: 0

  def top_nav(assigns) do
    assigns = assign(assigns, :container, @container)

    ~H"""
    <header class="bg-base-100/90 border-base-300 sticky top-0 z-40 border-b backdrop-blur">
      <div class={[@container, "flex items-center gap-4 py-2.5"]}>
        <.link
          navigate={~p"/"}
          class="font-display text-2xl leading-none font-extrabold tracking-tight"
        >
          S<span class="text-smovie">movie</span>
        </.link>

        <nav class="ml-4 hidden items-center gap-1 lg:ml-6 lg:flex">
          <.link
            :for={{path, label} <- main_sections()}
            navigate={path}
            aria-current={to_string(active?(@current_path, path))}
            class={[
              "rounded-lg px-3 py-2 text-sm transition-colors",
              active?(@current_path, path) && "bg-base-200 text-base-content",
              !active?(@current_path, path) && "text-base-content/60 hover:bg-base-200"
            ]}
          >
            {label}
          </.link>
        </nav>

        <div class="flex-1"></div>

        <.link
          navigate={~p"/recherche"}
          class="text-base-content/50 hover:text-base-content lg:hidden"
          aria-label={gettext("Rechercher")}
        >
          <.icon name="hero-magnifying-glass" class="size-5" />
        </.link>

        <.locale_switcher
          locale={@locale}
          current_path={@current_path}
          class="hidden lg:flex"
        />
        <.theme_toggle />

        <%= if @current_scope do %>
          <.link
            navigate={~p"/notifications"}
            class="text-base-content/50 hover:text-base-content relative"
            aria-label={gettext("Notifications")}
          >
            <.icon name="hero-bell" class="size-5" />
            <span
              :if={@unread_count > 0}
              data-role="unread-badge"
              class="bg-heat border-base-100 absolute -top-1 -right-1 grid min-w-4 place-items-center rounded-full border-2 px-1 font-mono text-[0.6rem] font-semibold text-[#2a0613]"
            >
              {@unread_count}
            </span>
          </.link>
          <.link
            navigate={~p"/u/#{@current_scope.user.username}"}
            title={@current_scope.user.display_name}
          >
            <.avatar user={@current_scope.user} size={:small} class="size-8 text-sm" />
          </.link>
          <.link
            href={~p"/users/log-out"}
            method="delete"
            class="text-base-content/50 hover:text-base-content"
            aria-label={gettext("Deconnexion")}
            title={gettext("Deconnexion")}
          >
            <.icon name="hero-arrow-right-start-on-rectangle" class="size-5" />
          </.link>
        <% else %>
          <.link navigate={~p"/users/log-in"} class="btn btn-ghost btn-sm">
            {gettext("Connexion")}
          </.link>
          <.link navigate={~p"/users/register"} class="btn btn-primary btn-sm hidden sm:inline-flex">
            {gettext("Inscription")}
          </.link>
        <% end %>
      </div>
    </header>
    """
  end

  @doc """
  Barre basse, jusqu'a `md:`.

  Cinq entrees, chacune d'au moins 44 px de haut, et l'encoche est reservee :
  sans `tabbar-safe`, la derniere rangee passe sous la barre de geste iOS.
  """
  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: "/"
  attr :unread_messages, :integer, default: 0

  def bottom_nav(assigns) do
    ~H"""
    <nav class="bg-base-100/95 border-base-300 tabbar-safe fixed inset-x-0 bottom-0 z-50 grid grid-cols-5 border-t px-1 pt-1.5 backdrop-blur md:hidden">
      <.link
        :for={{path, label, icon} <- bottom_sections()}
        navigate={path}
        aria-current={to_string(active?(@current_path, path))}
        class={[
          "flex min-h-11 flex-col items-center gap-0.5 py-1 font-mono text-[0.6rem] tracking-[0.05em] uppercase",
          active?(@current_path, path) && "text-base-content",
          !active?(@current_path, path) && "text-base-content/40"
        ]}
      >
        <span class="relative">
          <.icon name={icon} class={icon_class(active?(@current_path, path))} />
          <span
            :if={path == "/messages" and @unread_messages > 0}
            data-role="messages-badge"
            class="bg-heat border-base-100 absolute -top-1 -right-2 grid min-w-4 place-items-center rounded-full border-2 px-1 font-mono text-[0.55rem] font-semibold text-[#2a0613]"
          >
            {@unread_messages}
          </span>
        </span>
        {label}
      </.link>
    </nav>
    """
  end

  defp main_sections do
    [
      {~p"/", gettext("Accueil")},
      {~p"/reviews", gettext("Reviews")},
      {~p"/watchlist", gettext("Watchlist")},
      {~p"/messages", gettext("Messages")}
    ]
  end

  defp bottom_sections do
    [
      {~p"/", gettext("Accueil"), "hero-home"},
      {~p"/recherche", gettext("Chercher"), "hero-magnifying-glass"},
      {~p"/watchlist", gettext("A voir"), "hero-bookmark"},
      {~p"/messages", gettext("Messages"), "hero-chat-bubble-left-right"},
      {~p"/users/settings", gettext("Profil"), "hero-user-circle"}
    ]
  end

  # La racine ne doit s'allumer que sur elle-meme : un prefixe la rendrait
  # active sur toutes les pages.
  defp active?(current, "/"), do: current == "/"
  defp active?(current, path), do: current == path or String.starts_with?(current, path <> "/")

  defp icon_class(true), do: "size-5 text-smovie"
  defp icon_class(false), do: "size-5"

  @doc """
  Selecteur de langue.

  Un formulaire et non des liens : changer de langue modifie l'etat du compte
  ou du navigateur. Le chemin courant est renvoye pour revenir sur la meme page
  apres le changement.
  """
  attr :locale, :string, default: nil
  attr :current_path, :string, default: "/"
  attr :class, :string, default: nil

  def locale_switcher(assigns) do
    assigns = assign_new(assigns, :current, fn -> assigns.locale || Config.default_locale() end)

    ~H"""
    <div class={["flex items-center gap-1", @class]}>
      <.form
        :for={locale <- Config.locales()}
        for={%{}}
        action={~p"/locale/#{locale}"}
        method="put"
      >
        <input type="hidden" name="return_to" value={@current_path} />
        <button
          type="submit"
          class={[
            "btn btn-ghost btn-xs uppercase",
            locale == @current && "btn-active"
          ]}
          aria-current={locale == @current}
        >
          {locale}
        </button>
      </.form>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-[33%] h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-[33%] [[data-theme=dark]_&]:left-[66%] transition-[left]" />

      <button phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})} class="flex p-2">
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})} class="flex p-2">
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})} class="flex p-2">
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
