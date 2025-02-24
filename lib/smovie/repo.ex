defmodule Smovie.Repo do
  use Ecto.Repo,
    otp_app: :smovie,
    adapter: Ecto.Adapters.Postgres
end
