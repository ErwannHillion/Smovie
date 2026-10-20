defmodule Credo.Check.Warning.NoSysGetState do
  @moduledoc """
  Check Credo custom qui interdit l'utilisation de `:sys.get_state` dans les tests.

  Ce pattern couple les tests aux details d'implementation interne des processus
  (GenServer state). Les tests doivent verifier le comportement visible plutot
  que l'etat interne.

  ## Exemples

  Interdit :

      state = :sys.get_state(pid)
      assert state.counter == 1

  Preferer :

      assert has_element?(view, "#counter", "1")
      assert render(view) =~ "1"
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      `:sys.get_state` couple les tests aux details d'implementation interne
      des processus. Utilisez plutot `has_element?/3` ou `render/1` pour
      verifier le comportement visible.
      """
    ]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    # Ne pas analyser les fichiers .credo/ (evite que ce check se flag lui-meme)
    if String.contains?(source_file.filename, ".credo/") do
      []
    else
      do_run(source_file, params)
    end
  end

  defp do_run(source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> SourceFile.source()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, line_no}, issues ->
      if Regex.match?(~r/:\s*sys\.get_state/, line) do
        [issue_for(issue_meta, line_no, String.trim(line)) | issues]
      else
        issues
      end
    end)
  end

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(
      issue_meta,
      message:
        "Eviter :sys.get_state qui couple les tests aux details d'implementation. Utiliser has_element?/3 ou render/1 pour verifier le comportement visible.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
