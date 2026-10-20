defmodule SmovieWeb.UserSessionController do
  use SmovieWeb, :controller

  alias Smovie.Accounts
  alias SmovieWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, user, tokens_to_disconnect} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, gettext("Adresse e-mail ou mot de passe incorrect"))
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(
        %{assigns: %{current_scope: %{user: user}}} = conn,
        %{"user" => user_params} = params
      ) do
    # Le scaffold ecrivait `true = Accounts.sudo_mode?(user)` : un mode sudo
    # expire sortait en 500 avec un MatchError sans message, au lieu d'un refus
    # lisible (voir .claude/rules/elixir-code.md).
    if Accounts.sudo_mode?(user) do
      {:ok, _user, expired_tokens} = Accounts.update_user_password(user, user_params)

      # disconnect all existing LiveViews with old sessions
      UserAuth.disconnect_sessions(expired_tokens)

      conn
      |> put_session(:user_return_to, ~p"/users/settings")
      |> create(params, gettext("Mot de passe mis a jour."))
    else
      conn
      |> put_flash(:error, gettext("Votre session a expire. Reconnectez-vous pour continuer."))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
