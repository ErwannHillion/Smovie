defmodule SmovieWeb.MovieFormComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      <h3>Ajouter à la liste des films regardés</h3>
      <form phx-submit="save_watched_list">
        <input type="hidden" name="watched_list[id_movie]" value={@movie["id"]} />
        <label for="urating">Note :</label>
        <input type="number" name="watched_list[urating]" step="0.1" min="0" max="10" />
        <label for="udescription">Description :</label>
        <textarea name="watched_list[udescription]"></textarea>
        <label for="uwatcheddate">Date de visionnage :</label>
        <input type="date" name="watched_list[uwatcheddate]" />
        <button type="submit">Enregistrer</button>
      </form>
    </div>
    """
  end
end
