defmodule Credo.Check.Warning.NoDirectSocketAssigns do
  @moduledoc """
  Interdit l'accès direct à `socket.assigns.xxx` dans les modules LiveView.

  Préférer la déstructuration dans la signature de fonction pour plus de clarté
  et pour rendre explicites les dépendances de chaque fonction.

  ## Exemple invalide

      def handle_event("save", params, socket) do
        user = socket.assigns.current_user
        scope = socket.assigns.current_scope
        save(user, scope, params)
      end

  ## Exemple valide

      def handle_event("save", params, %{assigns: %{current_user: user, current_scope: scope}} = socket) do
        save(user, scope, params)
      end

  ## Exceptions

  Les accès dans les templates HEEx (`@variable`) ne sont pas concernés.
  Seuls les accès `socket.assigns.xxx` dans le code Elixir sont détectés.
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [
      excluded_files: []
    ]

  alias Credo.SourceFile

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

    String.contains?(trimmed, "socket.assigns.") and
      not String.starts_with?(trimmed, "#") and
      not String.starts_with?(trimmed, "@")
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
        "Accès direct à socket.assigns détecté. Déstructurer dans la signature de fonction.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
