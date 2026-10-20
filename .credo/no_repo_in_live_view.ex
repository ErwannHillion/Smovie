defmodule Credo.Check.Warning.NoRepoInLiveView do
  @moduledoc """
  Interdit les appels directs a `Repo.` dans les modules LiveView.

  Les LiveViews ne doivent pas contenir de logique d'acces a la base de donnees.
  Extraire ces appels dans le module Service ou Context correspondant.

  ## Exemple invalide

      def handle_event("delete", %{"id" => id}, socket) do
        item = Repo.get!(Item, id)
        Repo.delete(item)
      end

  ## Exemple valide

      def handle_event("delete", %{"id" => id}, socket) do
        item = MyService.get_item!(id)
        MyService.delete_item(item)
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [
      excluded_files: []
    ]

  alias Credo.SourceFile

  @repo_pattern ~r/Repo\.(get|get!|get_by|get_by!|one|one!|all|insert|insert!|update|update!|delete|delete!|preload|transaction|aggregate)\b/

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
    if match?(line), do: [issue_for(source_file, line_no, String.trim(line))], else: []
  end

  defp match?(line) do
    trimmed = String.trim_leading(line)

    not String.starts_with?(trimmed, "#") and
      Regex.match?(@repo_pattern, trimmed)
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
        "Appel direct a Repo detecte dans un LiveView. Extraire dans le module Service/Context.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
