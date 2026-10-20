defmodule Credo.Check.Warning.NoTrueMatch do
  @moduledoc """
  Check Credo custom qui interdit le pattern `true = expression`.

  Ce pattern leve un MatchError sans message exploitable en cas d'echec.
  Preferer un pattern match dans la signature de fonction ou un retour
  d'erreur explicite.

  ## Exemples

  Interdit :

      true = booking.user_id == scope.user.id

  Preferer :

      def update_booking(%Scope{user: %{id: user_id}}, %Booking{user_id: user_id} = booking, attrs) do
        ...
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      `true = expression` leve un MatchError generique en cas d'echec.
      Utilisez plutot un pattern match dans la signature de fonction
      ou retournez {:error, :unauthorized}.
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
      if Regex.match?(~r/^\s*true\s*=\s/, line) do
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
        "Eviter `true = ...` qui leve un MatchError generique. Preferer un pattern match en signature de fonction.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
