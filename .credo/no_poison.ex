defmodule Credo.Check.Consistency.NoPoison do
  @moduledoc """
  Check Credo custom qui interdit l'utilisation de Poison.

  Le projet utilise Jason comme bibliothèque JSON.
  Poison ne doit pas être utilisé.

  ## Exemples

  Interdit :

      Poison.encode!(data)
      Poison.decode(json)

  Préférer :

      Jason.encode!(data)
      Jason.decode(json)
  """

  use Credo.Check,
    base_priority: :high,
    category: :consistency,
    explanations: [
      check: """
      Le projet utilise Jason comme bibliothèque JSON.
      Remplacer `Poison.encode/decode` par `Jason.encode/decode`.
      """
    ]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    if String.contains?(source_file.filename, ".credo") do
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
      # La limite de mot est indispensable : sans elle, `HTTPoison.post` matche
      # `Poison.` et chaque appel HTTP du projet remontait DEUX fois, une par
      # check. Trente-trois faux positifs, sur un code qui n'utilise que Jason.
      if Regex.match?(~r/(?<![A-Za-z])Poison\./, line) and not comment?(line) do
        [issue_for(issue_meta, line_no, String.trim(line)) | issues]
      else
        issues
      end
    end)
  end

  defp comment?(line), do: String.trim_leading(line) |> String.starts_with?("#")

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(
      issue_meta,
      message: "Utiliser Jason au lieu de Poison pour le JSON.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
