defmodule SmovieWeb.ReviewLive.Show do
  @moduledoc """
  Une review en entier.
  """
  use SmovieWeb, :live_view

  alias Smovie.Reviews

  @impl true
  def mount(%{"id" => id}, _session, %{assigns: %{current_scope: scope}} = socket) do
    review = Reviews.get_review(id)

    # Une review invisible se comporte comme une review absente : repondre
    # « existe mais vous n'y avez pas droit » revelerait deja quelque chose.
    if review && Reviews.visible?(scope, review) do
      {:ok,
       socket
       |> assign(revealed: false, page_title: page_title(review))
       |> assign_review(review)}
    else
      raise SmovieWeb.ReviewLive.NotFound, id
    end
  end

  defp page_title(review), do: "#{review.user.display_name} · #{review.work.title}"

  defp assign_review(%{assigns: %{current_scope: scope}} = socket, review) do
    socket
    |> assign(
      review: review,
      comments: Reviews.list_comments(review),
      liked?: Reviews.liked?(scope, review)
    )
    |> assign_new(:comment_form, fn ->
      to_form(%{"body" => "", "parent_id" => nil}, as: :comment)
    end)
    |> assign_new(:replying_to, fn -> nil end)
  end

  @impl true
  def handle_event("reveal", _params, socket), do: {:noreply, assign(socket, revealed: true)}

  def handle_event("toggle_like", _params, %{assigns: %{current_scope: nil}} = socket) do
    {:noreply, redirect_to_login(socket)}
  end

  def handle_event(
        "toggle_like",
        _params,
        %{assigns: %{current_scope: scope, review: review}} = socket
      ) do
    Reviews.toggle_like(scope, review)

    {:noreply, assign_review(socket, Reviews.reload(review))}
  end

  def handle_event("reply_to", %{"comment-id" => id}, socket) do
    {:noreply, assign(socket, replying_to: id)}
  end

  def handle_event("cancel_reply", _params, socket) do
    {:noreply, assign(socket, replying_to: nil)}
  end

  def handle_event("comment", _params, %{assigns: %{current_scope: nil}} = socket) do
    {:noreply, redirect_to_login(socket)}
  end

  def handle_event(
        "comment",
        %{"comment" => params},
        %{assigns: %{current_scope: scope, review: review}} = socket
      ) do
    case Reviews.comment(scope, review, params) do
      {:ok, _comment} ->
        {:noreply,
         socket
         |> assign(replying_to: nil)
         |> assign(comment_form: to_form(%{"body" => "", "parent_id" => nil}, as: :comment))
         |> assign_review(Reviews.reload(review))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Ce commentaire n'a pas pu etre publie."))}
    end
  end

  def handle_event(
        "delete_comment",
        %{"comment-id" => id},
        %{assigns: %{current_scope: scope, review: review}} = socket
      ) do
    case Reviews.get_comment(id) do
      nil ->
        {:noreply, socket}

      comment ->
        Reviews.delete_comment(scope, comment)
        {:noreply, assign_review(socket, Reviews.reload(review))}
    end
  end

  defp redirect_to_login(socket) do
    socket
    |> put_flash(:info, gettext("Connectez-vous pour reagir aux reviews."))
    |> push_navigate(to: ~p"/users/log-in")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      current_path={@current_path}
      unread_count={@unread_count}
      unread_messages={@unread_messages}
    >
      <div class="max-w-2xl py-4">
        <.review_card review={@review} show_work full revealed={@revealed} />

        <button
          :if={@review.contains_spoilers and not @revealed}
          type="button"
          phx-click="reveal"
          class="btn btn-ghost btn-sm mt-3"
        >
          {gettext("Afficher les spoilers")}
        </button>

        <div class="border-base-300 mt-4 flex items-center gap-5 border-t pt-4 font-mono text-xs">
          <button
            type="button"
            phx-click="toggle_like"
            aria-pressed={to_string(@liked?)}
            class={[
              "flex min-h-11 items-center gap-2",
              if(@liked?, do: "text-heat", else: "text-base-content/50 hover:text-base-content")
            ]}
          >
            <.icon name="hero-heart" class="size-4" />
            {ngettext("%{count} j'aime", "%{count} j'aime", @review.likes_count,
              count: @review.likes_count
            )}
          </button>
          <span class="text-base-content/50 flex items-center gap-2">
            <.icon name="hero-chat-bubble-left" class="size-4" />
            {ngettext("%{count} commentaire", "%{count} commentaires", @review.comments_count,
              count: @review.comments_count
            )}
          </span>
        </div>

        <section class="mt-6">
          <.form for={@comment_form} id="comment_form" phx-submit="comment">
            <input type="hidden" name="comment[parent_id]" value={@replying_to} />
            <.input
              field={@comment_form[:body]}
              type="textarea"
              rows="3"
              label={
                if @replying_to, do: gettext("Votre reponse"), else: gettext("Votre commentaire")
              }
            />
            <div class="flex gap-2">
              <.button variant="primary">{gettext("Envoyer")}</.button>
              <button :if={@replying_to} type="button" phx-click="cancel_reply" class="btn btn-ghost">
                {gettext("Annuler la reponse")}
              </button>
            </div>
          </.form>

          <ul class="mt-5 flex flex-col gap-4">
            <li :for={comment <- @comments}>
              <.comment_item comment={comment} current_scope={@current_scope} />

              <ul
                :if={comment.replies != []}
                class="border-base-300 mt-3 flex flex-col gap-3 border-l pl-4"
              >
                <li :for={reply <- comment.replies}>
                  <.comment_item comment={reply} current_scope={@current_scope} reply />
                </li>
              </ul>
            </li>
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :comment, :map, required: true
  attr :current_scope, :map, default: nil
  attr :reply, :boolean, default: false

  defp comment_item(assigns) do
    ~H"""
    <article class="bg-base-200 rounded-lg p-3">
      <header class="flex items-center gap-2.5">
        <.user_chip user={@comment.user} navigate={"/u/#{@comment.user.username}"} size={:small} />
        <span class="text-base-content/40 ml-auto font-mono text-[0.65rem]">
          {Calendar.strftime(@comment.inserted_at, "%d/%m/%Y")}
        </span>
      </header>
      <p class="text-base-content/85 mt-2 text-sm leading-relaxed whitespace-pre-line">
        {@comment.body}
      </p>
      <footer class="text-base-content/40 mt-2 flex gap-4 font-mono text-[0.65rem]">
        <button
          :if={not @reply}
          type="button"
          phx-click="reply_to"
          phx-value-comment-id={@comment.id}
          class="hover:text-base-content"
        >
          {gettext("Repondre")}
        </button>
        <button
          :if={own_comment?(@current_scope, @comment)}
          type="button"
          phx-click="delete_comment"
          phx-value-comment-id={@comment.id}
          class="hover:text-heat"
        >
          {gettext("Supprimer")}
        </button>
      </footer>
    </article>
    """
  end

  defp own_comment?(%{user: %{id: id}}, %{user_id: id}), do: true
  defp own_comment?(_scope, _comment), do: false
end
