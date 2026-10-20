defmodule SmovieWeb.UserComponents do
  @moduledoc """
  Composants d'affichage des membres.
  """
  use Phoenix.Component
  use Gettext, backend: SmovieWeb.Gettext

  # Teintes de la palette. La couleur est derivee de l'identifiant, donc
  # stable : un membre garde le meme avatar d'une page a l'autre et d'une
  # session a l'autre, ce qui le rend reconnaissable dans une liste.
  @tints ~w(#a888f7 #f0a02e #ff5d87 #8fc0ce #83e0d0 #bda7dd #ff7a5c)

  @doc """
  Avatar d'un membre.

  En attendant le televersement, c'est l'initiale du nom affiche sur une
  couleur derivee de l'identifiant.
  """
  attr :user, :map, required: true
  attr :size, :atom, default: :default, values: [:small, :default, :large]
  attr :class, :string, default: nil

  def avatar(assigns) do
    ~H"""
    <span
      class={[
        "grid shrink-0 place-items-center rounded-full font-mono font-semibold text-[#190f2b]",
        avatar_size(@size),
        @class
      ]}
      style={"background-color: #{tint(@user)}"}
      aria-hidden="true"
    >
      {initial(@user)}
    </span>
    """
  end

  defp avatar_size(:small), do: "size-6 text-[0.6rem]"
  defp avatar_size(:default), do: "size-9 text-sm"
  defp avatar_size(:large), do: "size-16 text-2xl md:size-20 md:text-3xl"

  defp tint(%{id: id}) when is_integer(id), do: Enum.at(@tints, rem(id, length(@tints)))
  defp tint(_user), do: hd(@tints)

  defp initial(%{display_name: name}) when is_binary(name) and name != "",
    do: name |> String.first() |> String.upcase()

  defp initial(%{username: name}) when is_binary(name) and name != "",
    do: name |> String.first() |> String.upcase()

  defp initial(_user), do: "?"

  @doc """
  Identite d'un membre : avatar, nom affiche, username.
  """
  attr :user, :map, required: true
  attr :size, :atom, default: :default
  attr :navigate, :string, default: nil
  attr :class, :string, default: nil

  def user_chip(assigns) do
    ~H"""
    <.chip_wrapper navigate={@navigate} class={["flex min-w-0 items-center gap-2.5", @class]}>
      <.avatar user={@user} size={@size} />
      <span class="min-w-0">
        <span class="block truncate text-sm font-medium leading-tight">{@user.display_name}</span>
        <span class="text-base-content/50 block font-mono text-[0.65rem]">@{@user.username}</span>
      </span>
    </.chip_wrapper>
    """
  end

  attr :navigate, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp chip_wrapper(%{navigate: nil} = assigns) do
    ~H"<div class={@class}>{render_slot(@inner_block)}</div>"
  end

  defp chip_wrapper(assigns) do
    ~H"""
    <.link navigate={@navigate} class={@class}>{render_slot(@inner_block)}</.link>
    """
  end
end
