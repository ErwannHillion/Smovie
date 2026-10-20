defmodule SmovieWeb.ErrorHTML do
  @moduledoc """
  Pages d'erreur.

  Elles portent la mise en page de l'application plutot qu'un texte brut :
  une page blanche affichant « Not Found » donne l'impression d'un site casse,
  et prive le visiteur du seul geste utile — revenir a l'accueil.

  Elles n'utilisent pas `Layouts.app` : une erreur peut survenir avant que le
  scope, la locale ou les compteurs ne soient assignes, et un layout qui les
  exige ferait echouer le rendu de la page d'erreur elle-meme.
  """
  use SmovieWeb, :html

  def render("404.html", assigns) do
    assigns
    |> Map.merge(%{
      code: "404",
      title: gettext("Page introuvable"),
      message: gettext("Cette page n'existe pas, ou n'existe plus.")
    })
    |> error_page()
  end

  def render("500.html", assigns) do
    assigns
    |> Map.merge(%{
      code: "500",
      title: gettext("Quelque chose a casse"),
      message: gettext("L'erreur est de notre cote. Reessayez dans un instant.")
    })
    |> error_page()
  end

  def render(template, assigns) do
    assigns
    |> Map.merge(%{
      code: template |> String.split(".") |> List.first(),
      title: Phoenix.Controller.status_message_from_template(template),
      message: gettext("Cette requete n'a pas pu aboutir.")
    })
    |> error_page()
  end

  defp error_page(assigns) do
    ~H"""
    <main class="bg-base-100 text-base-content flex min-h-dvh flex-col justify-center px-6">
      <div class="mx-auto flex w-full max-w-md flex-col items-start gap-3">
        <a href="/" class="font-display text-2xl leading-none font-extrabold tracking-tight">
          S<span class="text-smovie">movie</span>
        </a>
        <p class="text-base-content/40 font-mono text-xs tracking-[0.2em]">{@code}</p>
        <h1 class="font-display text-4xl leading-none font-bold tracking-tight">{@title}</h1>
        <p class="text-base-content/70">{@message}</p>
        <a href="/" class="btn btn-primary btn-sm mt-2">{gettext("Retour a l'accueil")}</a>
      </div>
    </main>
    """
  end
end
