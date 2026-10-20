defmodule SmovieWeb.MessagingLive.NotFound do
  @moduledoc """
  Conversation absente ou inaccessible.

  Les deux cas donnent une 404 : repondre « cette conversation existe mais
  vous n'en etes pas » confirmerait deja son existence a qui tente des
  identifiants au hasard.
  """
  defexception [:reason]

  @impl true
  def exception(reason), do: %__MODULE__{reason: reason}

  @impl true
  def message(%__MODULE__{reason: reason}), do: "conversation inaccessible : #{inspect(reason)}"

  defimpl Plug.Exception do
    def status(_exception), do: 404
    def actions(_exception), do: []
  end
end
