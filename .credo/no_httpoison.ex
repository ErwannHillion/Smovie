defmodule Credo.Check.Consistency.NoHTTPoison do
  @moduledoc """
  Check Credo custom qui interdit l'utilisation de HTTPoison.

  Le projet utilise Req comme client HTTP.
  HTTPoison ne doit pas être utilisé.

  ## Exemples

  Interdit :

      HTTPoison.get(url)
      %HTTPoison.Response{status_code: 200}

  Préférer :

      Req.get(url)
      %Req.Response{status: 200}
  """

  use Credo.Check,
    base_priority: :high,
    category: :consistency,
    explanations: [
      check: """
      Le projet utilise Req comme client HTTP.
      Remplacer `HTTPoison` par `Req`.
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
      if Regex.match?(~r/HTTPoison/, line) and not comment?(line) do
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
      message: "Utiliser Req au lieu de HTTPoison pour les requêtes HTTP.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
