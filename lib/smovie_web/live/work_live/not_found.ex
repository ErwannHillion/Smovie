defmodule SmovieWeb.WorkLive.NotFound do
  @moduledoc """
  Oeuvre inexistante.

  Sort en 404 : une fiche absente est un cas normal, pas une panne.
  """
  defexception [:slug]

  @impl true
  def exception(slug), do: %__MODULE__{slug: slug}

  @impl true
  def message(%__MODULE__{slug: slug}), do: "aucune oeuvre nommee #{inspect(slug)}"

  defimpl Plug.Exception do
    def status(_exception), do: 404
    def actions(_exception), do: []
  end
end
