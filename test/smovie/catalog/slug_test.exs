defmodule Smovie.Catalog.SlugTest do
  use ExUnit.Case, async: true

  alias Smovie.Catalog.Slug

  describe "slugify/1" do
    test "depouille les accents plutot que de les encoder" do
      # Une URL lisible se recopie a la main et se dicte au telephone.
      assert Slug.slugify("Dune, deuxième partie") == "dune-deuxieme-partie"
      assert Slug.slugify("La Zone d'intérêt") == "la-zone-d-interet"
      assert Slug.slugify("Amélie Poulain") == "amelie-poulain"
    end

    test "fusionne les separateurs et taille les bords" do
      assert Slug.slugify("  Le  Comte   de Monte-Cristo !! ") == "le-comte-de-monte-cristo"
    end

    test "retombe sur un segment valide quand il ne reste rien" do
      assert Slug.slugify("!!!") == "oeuvre"
      assert Slug.slugify("") == "oeuvre"
      assert Slug.slugify(nil) == ""
    end

    test "gere les alphabets non latins sans produire de vide" do
      assert Slug.slugify("七人の侍") == "oeuvre"
    end
  end

  describe "build/2" do
    test "suffixe l'annee pour desambiguiser" do
      assert Slug.build("Dune", ~D[2021-09-15]) == "dune-2021"
      assert Slug.build("Dune", ~D[1984-12-14]) == "dune-1984"
    end

    test "se passe d'annee quand la date manque" do
      assert Slug.build("Dune", nil) == "dune"
    end
  end

  describe "build_season/2 et build_episode/3" do
    test "la saison porte le slug de la serie" do
      assert Slug.build_season("severance", 2) == "severance-saison-2"
    end

    test "l'episode emploie la notation SxxEyy" do
      # C'est la notation que les gens emploient, et elle se trie correctement.
      assert Slug.build_episode("severance", 2, 7) == "severance-s02e07"
      assert Slug.build_episode("severance", 10, 12) == "severance-s10e12"
    end
  end

  describe "unique/2" do
    test "rend le slug tel quel s'il est libre" do
      assert Slug.unique("dune-2024", fn _ -> false end) == "dune-2024"
    end

    test "suffixe jusqu'a trouver un libre" do
      pris = MapSet.new(["dune", "dune-2", "dune-3"])
      assert Slug.unique("dune", &MapSet.member?(pris, &1)) == "dune-4"
    end
  end
end
