defmodule Credo.Check.Warning.NoDirectApplicationGetEnv do
  @moduledoc """
  Interdit l'appel direct a `Application.get_env(:intranet, ...)` dans le code
  metier.

  Toute lecture de configuration applicative doit passer par le module
  centralise `Intranet.Config`.

  ## Fichiers exclus

  - `lib/intranet/config.ex`  (le module centralise lui-meme)
  - `lib/intranet/application.ex` (demarrage OTP)

  ## Exemple invalide

      def send_email do
        sender = Application.get_env(:intranet, :email_sender)
        ...
      end

  ## Exemple valide

      def send_email do
        sender = Intranet.Config.email_sender()
        ...
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning

  alias Credo.SourceFile

  @pattern "Application.get_env(:intranet"

  # Fichiers autorises a utiliser Application.get_env(:intranet, ...) directement
  @excluded_suffixes [
    "lib/intranet/config.ex",
    "lib/intranet/application.ex"
  ]

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

    if String.contains?(trimmed, @pattern) and not comment_or_string?(trimmed) do
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
        "Appel direct a Application.get_env(:intranet, ...) interdit. " <>
          "Utiliser Intranet.Config a la place.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
