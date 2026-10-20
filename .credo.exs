# Configuration Credo.
#
# Sans ce fichier, `mix credo --strict` tourne avec les checks par defaut et
# n'execute AUCUN des dix checks custom du dossier `.credo/` : ils existaient
# dans le depot sans jamais s'appliquer.
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "config/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      requires: ["./.credo/"],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        extra: [
          # Les dix checks du depot, par ordre alphabetique de fichier.
          {Credo.Check.Consistency.FilePathNaming, []},
          {Credo.Check.Consistency.NoHTTPoison, []},
          {Credo.Check.Consistency.NoPoison, []},
          {Credo.Check.Readability.NoSingleClauseWith, []},
          {Credo.Check.Warning.NoDirectApplicationGetEnv, []},
          {Credo.Check.Warning.NoDirectSocketAssigns, []},
          {Credo.Check.Warning.NoRepoInLiveView, []},
          {Credo.Check.Warning.NoSysGetState, []},
          {Credo.Check.Warning.NoTrueMatch, []},
          {Credo.Check.Warning.NoUnnecessaryStringToInteger, []}
        ],
        disabled: [
          # Les moduledoc arrivent avec les contextes, pas sur les schemas Ecto.
          {Credo.Check.Readability.ModuleDoc, []}
        ]
      }
    }
  ]
}
