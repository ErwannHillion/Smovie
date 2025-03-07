defmodule Smovie.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SmovieWeb.Telemetry,
      Smovie.Repo,
      {DNSCluster, query: Application.get_env(:smovie, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Smovie.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Smovie.Finch},
      # Start a worker by calling: Smovie.Worker.start_link(arg)
      # {Smovie.Worker, arg},
      # Start to serve requests, typically the last entry

      # SALAD UI NEED THIS
      TwMerge.Cache,

      #
      SmovieWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Smovie.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SmovieWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
