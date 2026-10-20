defmodule SmovieWeb.WorkComponentsTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SmovieWeb.WorkComponents

  describe "rating_stars/1" do
    test "remplit la moitie des etoiles pour 5 demi-etoiles" do
      html = render_component(&rating_stars/1, value: 5)

      assert html =~ "width: 50.0%"
    end

    test "remplit tout pour 10 demi-etoiles" do
      assert render_component(&rating_stars/1, value: 10) =~ "width: 100.0%"
    end

    test "ne remplit rien pour 0" do
      assert render_component(&rating_stars/1, value: 0) =~ "width: 0.0%"
    end

    test "annonce la note aux lecteurs d'ecran" do
      html = render_component(&rating_stars/1, value: 9)

      assert html =~ "4,5 sur 5"
    end
  end

  describe "format_stars/1" do
    test "convertit les demi-etoiles en note sur 5" do
      assert format_stars(1) == "0,5"
      assert format_stars(7) == "3,5"
      assert format_stars(10) == "5,0"
    end

    test "utilise le point decimal en anglais" do
      Gettext.put_locale(SmovieWeb.Gettext, "en")
      assert format_stars(7) == "3.5"
    after
      Gettext.put_locale(SmovieWeb.Gettext, "fr")
    end
  end

  describe "rating_input/1" do
    test "pose dix zones de contact, une par demi-etoile" do
      html = render_component(&rating_input/1, value: nil)

      assert html |> String.split("phx-value-value=") |> length() == 11
    end

    test "chaque zone fait au moins 44 px de haut" do
      # Au doigt, dix petits boutons cote a cote seraient intouchables.
      assert render_component(&rating_input/1, value: nil) =~ "min-h-11"
    end

    test "marque la note courante comme selectionnee" do
      html = render_component(&rating_input/1, value: 7)

      assert html =~ ~s(aria-pressed="true")
      assert html |> String.split(~s(aria-pressed="true")) |> length() == 2
      assert html =~ "3,5"
    end

    test "invite a noter quand aucune note n'est posee" do
      assert render_component(&rating_input/1, value: nil) =~ "Glissez pour noter"
    end
  end

  describe "score_block/1" do
    test "masque la moyenne Smovie en dessous du seuil de votes" do
      html = render_component(&score_block/1, smovie_average: 4.8, smovie_count: 1)

      # Une moyenne sur une seule note est plus trompeuse qu'utile.
      refute html =~ "4,8"
      assert html =~ "1 note"
    end

    test "affiche la moyenne au-dela du seuil" do
      html = render_component(&score_block/1, smovie_average: 4.4, smovie_count: 120)

      assert html =~ "4,4"
      assert html =~ "120 notes"
    end

    test "nomme la source reelle de la note presse" do
      html =
        render_component(&score_block/1,
          smovie_count: 0,
          press_score: 8.5,
          press_source: "IMDb"
        )

      assert html =~ "IMDb"
      assert html =~ "8,5"
    end

    test "affiche un tiret plutot qu'un zero quand la note manque" do
      html = render_component(&score_block/1, smovie_count: 0)

      assert html =~ "—"
      refute html =~ "0,0"
    end
  end

  describe "poster/1" do
    test "sert l'affiche en plusieurs largeurs" do
      html = render_component(&poster/1, title: "Dune", poster_path: "/abc.jpg")

      assert html =~ "w185/abc.jpg 185w"
      assert html =~ "w342/abc.jpg 342w"
      assert html =~ "w500/abc.jpg 500w"
    end

    test "charge l'image en differe par defaut" do
      html = render_component(&poster/1, title: "Dune", poster_path: "/abc.jpg")

      assert html =~ ~s(loading="lazy")
    end

    test "charge l'image sans attendre quand c'est demande" do
      html = render_component(&poster/1, title: "Dune", poster_path: "/a.jpg", eager: true)

      assert html =~ ~s(loading="eager")
    end

    test "retombe sur le titre sans affiche" do
      html = render_component(&poster/1, title: "Sans affiche")

      refute html =~ "<img"
      assert html =~ "Sans affiche"
    end

    test "rend un lien quand une destination est donnee" do
      html = render_component(&poster/1, title: "Dune", navigate: "/film/dune")

      assert html =~ ~s(href="/film/dune")
    end

    test "rend un div sans destination, pour pouvoir etre imbrique" do
      # Un lien dans un lien est du HTML invalide : la variante div permet de
      # poser une affiche dans une carte elle-meme cliquable.
      html = render_component(&poster/1, title: "Dune")

      refute html =~ "<a "
    end
  end

  describe "poster_grid/1" do
    test "part de trois colonnes sur mobile" do
      html = render_component(&poster_grid/1, %{inner_block: []})

      assert html =~ "grid-cols-3"
      assert html =~ "md:grid-cols-6"
    end
  end
end
