defmodule SmovieWeb.WatchLaterLive.FormComponent do
  use SmovieWeb, :live_component

  alias Smovie.Movies

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage watch_later records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="watch_later-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:id_movie]} type="number" label="Id movie" />
        <.input field={@form[:movie_description]} type="text" label="Movie description" />
        <.input field={@form[:movie_title]} type="text" label="Movie title" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Watch later</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{watch_later: watch_later} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Movies.change_watch_later(watch_later))
     end)}
  end

  @impl true
  def handle_event("validate", %{"watch_later" => watch_later_params}, socket) do
    changeset = Movies.change_watch_later(socket.assigns.watch_later, watch_later_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"watch_later" => watch_later_params}, socket) do
    save_watch_later(socket, socket.assigns.action, watch_later_params)
  end

  defp save_watch_later(socket, :edit, watch_later_params) do
    case Movies.update_watch_later(socket.assigns.watch_later, watch_later_params) do
      {:ok, watch_later} ->
        notify_parent({:saved, watch_later})

        {:noreply,
         socket
         |> put_flash(:info, "Watch later updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_watch_later(socket, :new, watch_later_params) do
    case Movies.create_watch_later(watch_later_params) do
      {:ok, watch_later} ->
        notify_parent({:saved, watch_later})

        {:noreply,
         socket
         |> put_flash(:info, "Watch later created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
