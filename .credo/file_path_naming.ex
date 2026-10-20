defmodule Credo.Check.Consistency.FilePathNaming do
  @moduledoc """
  Vérifie que les chemins de fichiers et répertoires suivent les conventions Elixir/Phoenix.

  Les noms de fichiers et répertoires doivent être en snake_case lowercase.
  Seuls les noms de modules (defmodule) utilisent PascalCase.

  Cette règle s'applique aux fichiers dans lib/, test/ et priv/.

  ## Exemples invalides

      # ❌ Majuscule dans le nom de répertoire
      lib/intranet_web/live/Admin/admin_live.ex

      # ❌ Majuscule dans le nom de fichier
      lib/intranet_web/plugs/Locale.ex

  ## Exemples valides

      # ✅ Tout en lowercase/snake_case
      lib/intranet_web/live/admin/admin_live.ex
      lib/intranet_web/plugs/locale.ex

  """

  use Credo.Check,
    base_priority: :high,
    category: :consistency

  @doc false
  def run(%SourceFile{filename: filename} = source_file, params) do
    # Checker les fichiers dans lib/, test/ et priv/
    if should_check_file?(filename) do
      check_path_naming(source_file, filename, params)
    else
      []
    end
  end

  defp should_check_file?(filename) do
    String.starts_with?(filename, ["lib/", "test/", "priv/"])
  end

  defp check_path_naming(source_file, filename, params) do
    issues = []

    # Vérifier les répertoires
    issues = issues ++ check_directory_names(source_file, filename, params)

    # Vérifier le nom du fichier
    issues = issues ++ check_file_name(source_file, filename, params)

    issues
  end

  defp check_directory_names(source_file, filename, params) do
    path_parts =
      filename
      |> Path.dirname()
      |> Path.split()

    path_parts
    |> Enum.with_index()
    |> Enum.flat_map(fn {part, index} ->
      if has_uppercase?(part) and part not in ["lib", "intranet_web"] do
        [
          issue_for(
            source_file,
            params,
            "Nom de répertoire avec majuscule: '#{part}' (chemin: #{Enum.join(Enum.take(path_parts, index + 1), "/")})"
          )
        ]
      else
        []
      end
    end)
  end

  defp check_file_name(source_file, filename, params) do
    basename = Path.basename(filename, ".ex")

    if has_uppercase?(basename) do
      [
        issue_for(
          source_file,
          params,
          "Nom de fichier avec majuscule: '#{basename}.ex'. Utilisez snake_case lowercase."
        )
      ]
    else
      []
    end
  end

  defp has_uppercase?(string) do
    String.match?(string, ~r/[A-Z]/)
  end

  defp issue_for(source_file, params, message) do
    format_issue(
      source_file,
      message: message,
      trigger: source_file.filename,
      line_no: 1,
      priority: params[:priority] || :high
    )
  end
end
