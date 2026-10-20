defmodule SmovieWeb.UserLive.Registration do
  use SmovieWeb, :live_view

  alias Smovie.Accounts
  alias Smovie.Accounts.User

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      current_path={@current_path}
    >
      <div class="mx-auto max-w-sm">
        <.header class="text-center">
          {gettext("Creer un compte")}
          <:subtitle>
            {gettext("Deja inscrit ?")}
            <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
              {gettext("Connectez-vous")}
            </.link>
          </:subtitle>
        </.header>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label={gettext("Adresse e-mail")}
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />

          <.button
            variant="primary"
            phx-disable-with={gettext("Creation du compte...")}
            class="w-full"
          >
            {gettext("Creer mon compte")}
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: SmovieWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{})

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Un message a ete envoye a %{email}. Ouvrez-le pour confirmer votre compte.",
             email: user.email
           )
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
