defmodule Credo.Check.Warning.NoUnnecessaryStringToInteger do
  @moduledoc """
  Détecte les appels `String.to_integer/1` et `Integer.parse/1` dans les modules LiveView.

  Dans les handlers LiveView (`handle_event`, `handle_params`, `handle_info`),
  les IDs reçus en string depuis le front-end n'ont généralement pas besoin
  d'être convertis manuellement : Ecto gère le casting automatiquement,
  y compris via les fonctions de contexte (`get_item!/1`, etc.).

  ## Exemple invalide

      def handle_event("select", %{"id" => id}, socket) do
        item = MyService.get_item!(String.to_integer(id))
        {:noreply, assign(socket, :item, item)}
      end

  ## Exemple valide

      def handle_event("select", %{"id" => id}, socket) do
        item = MyService.get_item!(id)
        {:noreply, assign(socket, :item, item)}
      end

  ## Note

  Certains cas légitimes existent (calculs arithmétiques, comparaisons numériques).
  Ce check est une suggestion (priorité basse) pour encourager la revue au cas par cas.
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [
      excluded_files: []
    ]

  alias Credo.SourceFile

  @patterns ["String.to_integer(", "String.to_integer!(", "Integer.parse("]

  @doc false
  def run(%SourceFile{} = source_file, params) do
    if live_view_file?(source_file.filename) and
         not excluded?(source_file.filename, params) do
      source_file
      |> SourceFile.lines()
      |> Enum.flat_map(&check_line(&1, source_file))
    else
      []
    end
  end

  defp check_line({line_no, line}, source_file) do
    case find_pattern(line) do
      nil -> []
      pattern -> [issue_for(source_file, line_no, pattern)]
    end
  end

  defp find_pattern(line) do
    trimmed = String.trim_leading(line)

    if String.starts_with?(trimmed, "#") do
      nil
    else
      Enum.find(@patterns, &String.contains?(line, &1))
    end
  end

  defp live_view_file?(filename) do
    String.contains?(filename, "/live/") and String.ends_with?(filename, ".ex")
  end

  defp excluded?(filename, params) do
    excluded = Keyword.get(params, :excluded_files, [])
    Enum.any?(excluded, &String.contains?(filename, &1))
  end

  defp issue_for(source_file, line_no, trigger) do
    format_issue(
      source_file,
      message:
        "#{trigger}) détecté dans un LiveView. Ecto gère le casting automatiquement — vérifier si la conversion est réellement nécessaire.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
