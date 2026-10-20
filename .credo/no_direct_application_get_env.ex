defmodule Credo.Check.Warning.NoDirectApplicationGetEnv do
  @moduledoc """
  Interdit la lecture directe de la configuration applicative dans le code
  metier.

  Toute lecture de configuration applicative doit passer par le module
  centralise `Smovie.Config`.

  ## Fichier exclu

  - `lib/smovie/config.ex` (le module centralise lui-meme)

  ## Exemple invalide

      def api_key do
        Application.get_env(:smovie, :tmdb)[:api_key]
      end

  ## Exemple valide

      def api_key do
        Smovie.Config.tmdb_api_key()
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning

  alias Credo.SourceFile

  # Couvre get_env/2, get_env/3, fetch_env!/2 et fetch_env/2.
  @patterns [
    "Application.get_env(:smovie",
    "Application.fetch_env!(:smovie",
    "Application.fetch_env(:smovie"
  ]

  # Seul Smovie.Config lit la configuration applicative.
  @excluded_suffixes ["lib/smovie/config.ex"]

  @doc false
  def run(%SourceFile{} = source_file, _params) do
    filename = source_file.filename

    if not lib_file?(filename) or excluded?(filename) do
      []
    else
      source_file
      |> SourceFile.lines()
      |> Enum.flat_map(&check_line(&1, source_file))
    end
  end

  defp check_line({line_no, line}, source_file) do
    trimmed = String.trim_leading(line)

    if Enum.any?(@patterns, &String.contains?(trimmed, &1)) and not comment_or_string?(trimmed) do
      [issue_for(source_file, line_no, String.trim(line))]
    else
      []
    end
  end

  # Ignorer les commentaires et les chaines de documentation
  defp comment_or_string?(trimmed) do
    String.starts_with?(trimmed, "#") or
      String.starts_with?(trimmed, "@moduledoc") or
      String.starts_with?(trimmed, "@doc") or
      String.starts_with?(trimmed, "\"\"\"") or
      String.starts_with?(trimmed, "\"")
  end

  # Ne verifier que les fichiers dans lib/
  defp lib_file?(filename) do
    String.contains?(filename, "/lib/") or String.starts_with?(filename, "lib/")
  end

  defp excluded?(filename) do
    Enum.any?(@excluded_suffixes, fn suffix ->
      String.ends_with?(filename, suffix) or
        String.ends_with?(filename, "/" <> suffix)
    end)
  end

  defp issue_for(source_file, line_no, trigger) do
    format_issue(
      source_file,
      message:
        "Lecture directe de la configuration applicative interdite. " <>
          "Utiliser Smovie.Config a la place.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
