defmodule SmovieWeb.WatchedListLive.FormComponent do
  use SmovieWeb, :live_component

  alias Smovie.Movies

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage watched_list records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="watched_list-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:urating]} type="number" label="Urating" step="any" />
        <.input field={@form[:udescription]} type="text" label="Udescription" />
        <.input field={@form[:uwatcheddate]} type="date" label="Uwatcheddate" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Watched list</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{watched_list: watched_list} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Movies.change_watched_list(watched_list))
     end)}
  end

  @impl true
  def handle_event("validate", %{"watched_list" => watched_list_params}, socket) do
    changeset = Movies.change_watched_list(socket.assigns.watched_list, watched_list_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"watched_list" => watched_list_params}, socket) do
    save_watched_list(socket, socket.assigns.action, watched_list_params)
  end

  defp save_watched_list(socket, :edit, watched_list_params) do
    case Movies.update_watched_list(socket.assigns.watched_list, watched_list_params) do
      {:ok, watched_list} ->
        notify_parent({:saved, watched_list})

        {:noreply,
         socket
         |> put_flash(:info, "Watched list updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_watched_list(socket, :new, watched_list_params) do
    case Movies.create_watched_list(watched_list_params) do
      {:ok, watched_list} ->
        notify_parent({:saved, watched_list})

        {:noreply,
         socket
         |> put_flash(:info, "Watched list created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
