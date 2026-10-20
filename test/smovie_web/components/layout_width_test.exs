defmodule SmovieWeb.LayoutWidthTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "gouttiere" do
    test "la page n'est plus bridee a max-w-6xl", %{conn: conn} do
      # Sur un ecran de 1920, max-w-6xl laissait deux bandes vides de 380 px.
      {:ok, _lv, html} = live(conn, ~p"/")

      refute html =~ "max-w-6xl"
      assert html =~ "max-w-[120rem]"
    end

    test "la gouttiere grandit par paliers", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      for classe <- ~w(px-4 sm:px-6 lg:px-10 xl:px-14), do: assert(html =~ classe)
    end

    test "le bandeau et le contenu partagent la meme gouttiere", %{conn: conn} do
      # Sans quoi le logo ne s'aligne pas sur la premiere affiche.
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html |> String.split("max-w-[120rem]") |> length() >= 3
    end
  end

  describe "repli de la barre haute" do
    test "les liens principaux attendent lg", %{conn: conn} do
      # A 768 px, quatre liens plus les controles debordaient du cadre.
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "lg:flex"
      refute html =~ ~s(class="ml-6 hidden items-center gap-1 md:flex")
    end

    test "le selecteur de langue se replie sous lg", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "hidden lg:flex"
    end

    test "la loupe reste visible tant que la navigation est repliee", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "lg:hidden"
    end
  end
end
