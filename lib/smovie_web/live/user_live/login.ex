defmodule SmovieWeb.UserLive.Login do
  use SmovieWeb, :live_view

  alias Smovie.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      current_path={@current_path}
    >
      <div class="mx-auto max-w-sm space-y-4">
        <.header class="text-center">
          <p>{gettext("Connexion")}</p>
          <:subtitle>
            <%= if @current_scope do %>
              {gettext(
                "Vous devez vous reconnecter pour effectuer une action sensible sur votre compte."
              )}
            <% else %>
              {gettext("Pas encore de compte ?")} <.link
                navigate={~p"/users/register"}
                class="font-semibold text-brand hover:underline"
                phx-no-format
              >{gettext("Inscrivez-vous")}</.link>
            <% end %>
          </:subtitle>
        </.header>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>{gettext("L'adaptateur mail local est actif.")}</p>
            <p>
              {gettext("Les messages envoyes sont consultables sur")} <.link
                href="/dev/mailbox"
                class="underline"
              >{gettext("la page mailbox")}</.link>.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label={gettext("Adresse e-mail")}
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="w-full" variant="primary">
            {gettext("Recevoir un lien de connexion")} <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="divider">{gettext("ou")}</div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label={gettext("Adresse e-mail")}
            autocomplete="username"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label={gettext("Mot de passe")}
            autocomplete="current-password"
          />
          <.input
            :if={!@current_scope}
            field={f[:remember_me]}
            type="checkbox"
            label={gettext("Rester connecte")}
          />
          <.button class="w-full" variant="primary">
            {gettext("Se connecter")} <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, %{assigns: %{flash: flash} = assigns} = socket) do
    email =
      Phoenix.Flash.get(flash, :email) ||
        get_in(assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      gettext(
        "Si cette adresse est enregistree, vous recevrez sous peu les instructions de connexion."
      )

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:smovie, Smovie.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
