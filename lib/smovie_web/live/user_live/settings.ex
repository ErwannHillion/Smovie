defmodule SmovieWeb.UserLive.Settings do
  use SmovieWeb, :live_view

  on_mount {SmovieWeb.UserAuth, :require_sudo_mode}

  alias Smovie.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      current_path={@current_path}
    >
      <.header class="text-center">
        {gettext("Parametres du compte")}
        <:subtitle>{gettext("Gerez votre adresse e-mail et votre mot de passe")}</:subtitle>
      </.header>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label={gettext("Adresse e-mail")}
          autocomplete="username"
          required
        />
        <.button variant="primary" phx-disable-with={gettext("Modification...")}>
          {gettext("Modifier mon adresse")}
        </.button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/users/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_user_email"
          autocomplete="username"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label={gettext("Nouveau mot de passe")}
          autocomplete="new-password"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label={gettext("Confirmer le nouveau mot de passe")}
          autocomplete="new-password"
        />
        <.button variant="primary" phx-disable-with={gettext("Enregistrement...")}>
          {gettext("Enregistrer le mot de passe")}
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  def mount(%{"token" => token}, _session, %{assigns: %{current_scope: %{user: user}}} = socket) do
    socket =
      case Accounts.update_user_email(user, token) do
        :ok ->
          put_flash(socket, :info, gettext("Adresse e-mail modifiee."))

        :error ->
          put_flash(
            socket,
            :error,
            gettext("Ce lien de changement d'adresse est invalide ou a expire.")
          )
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket) do
    email_changeset = Accounts.change_user_email(user, %{}, validate_email: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event(
        "validate_email",
        %{"user" => user_params},
        %{assigns: %{current_scope: %{user: user}}} = socket
      ) do
    email_form =
      user
      |> Accounts.change_user_email(user_params, validate_email: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event(
        "update_email",
        %{"user" => user_params},
        %{assigns: %{current_scope: %{user: user}}} = socket
      ) do
    case authorize_sudo(user, &Accounts.change_user_email(&1, user_params)) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info =
          gettext("Un lien de confirmation a ete envoye a la nouvelle adresse.")

        {:noreply, socket |> put_flash(:info, info)}

      {:error, :sudo_mode_expired} ->
        {:noreply, redirect_to_reauthentication(socket)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event(
        "validate_password",
        %{"user" => user_params},
        %{assigns: %{current_scope: %{user: user}}} = socket
      ) do
    password_form =
      user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event(
        "update_password",
        %{"user" => user_params},
        %{assigns: %{current_scope: %{user: user}}} = socket
      ) do
    case authorize_sudo(user, &Accounts.change_user_password(&1, user_params)) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      {:error, :sudo_mode_expired} ->
        {:noreply, redirect_to_reauthentication(socket)}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  # Le scaffold Phoenix ecrivait `true = Accounts.sudo_mode?(user)`. Un mode sudo
  # expire est un cas normal, pas un bug : le match levait un MatchError sans
  # message, qui sort en 500 au lieu de renvoyer l'utilisateur vers une
  # reauthentification (voir .claude/rules/elixir-code.md).
  defp authorize_sudo(user, fun) do
    if Accounts.sudo_mode?(user) do
      fun.(user)
    else
      {:error, :sudo_mode_expired}
    end
  end

  defp redirect_to_reauthentication(socket) do
    socket
    |> put_flash(:error, gettext("Votre session a expire. Reconnectez-vous pour continuer."))
    |> push_navigate(to: ~p"/users/log-in")
  end
end
