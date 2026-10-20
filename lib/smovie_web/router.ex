defmodule SmovieWeb.Router do
  use SmovieWeb, :router

  import SmovieWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SmovieWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug SmovieWeb.Plugs.ContentSecurityPolicy
    plug :fetch_current_scope_for_user
    plug SmovieWeb.Plugs.Locale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SmovieWeb do
    pipe_through :browser

    put "/locale/:locale", LocaleController, :update

    live_session :default,
      on_mount: [{SmovieWeb.UserAuth, :mount_current_scope}, SmovieWeb.Hooks.Locale] do
      live "/", HomeLive

      # Sections dont la navigation existe deja : voir SmovieWeb.SoonLive.
      live "/reviews", ReviewLive.Index
      live "/recherche", SoonLive, :search
      live "/watchlist", SoonLive, :watchlist
      live "/messages", SoonLive, :messages

      live "/u/:username", ProfileLive
      live "/u/:username/abonnements", NetworkLive, :following
      live "/u/:username/abonnes", NetworkLive, :followers

      live "/review/:id", ReviewLive.Show

      live "/film/:slug", WorkLive.Show, :movie
      live "/serie/:slug", WorkLive.Show, :tv_show
      live "/serie/:slug/saison/:number", WorkLive.Season
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", SmovieWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:smovie, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SmovieWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", SmovieWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SmovieWeb.UserAuth, :require_authenticated}, SmovieWeb.Hooks.Locale] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", SmovieWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{SmovieWeb.UserAuth, :mount_current_scope}, SmovieWeb.Hooks.Locale] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
