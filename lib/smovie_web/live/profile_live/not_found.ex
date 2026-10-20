defmodule SmovieWeb.ProfileLive.NotFound do
  @moduledoc """
  Profil inexistant.

  Implemente `Plug.Exception` pour sortir en 404 : sans cela, un username
  inconnu produirait une 500 et polluerait le suivi d'erreurs alors qu'il
  s'agit d'un cas de fonctionnement normal.
  """
  defexception [:username]

  @impl true
  def exception(username), do: %__MODULE__{username: username}

  @impl true
  def message(%__MODULE__{username: username}), do: "aucun membre nomme #{inspect(username)}"

  defimpl Plug.Exception do
    def status(_exception), do: 404
    def actions(_exception), do: []
  end
end
