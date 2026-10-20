defmodule SmovieWeb.ReviewLive.NotFound do
  @moduledoc """
  Review absente ou non visible.

  Les deux cas donnent la meme reponse : repondre « existe mais vous n'y avez
  pas droit » revelerait deja quelque chose d'une review privee.
  """
  defexception [:id]

  @impl true
  def exception(id), do: %__MODULE__{id: id}

  @impl true
  def message(%__MODULE__{id: id}), do: "aucune review accessible ##{id}"

  defimpl Plug.Exception do
    def status(_exception), do: 404
    def actions(_exception), do: []
  end
end
