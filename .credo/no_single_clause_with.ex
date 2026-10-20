defmodule Credo.Check.Readability.NoSingleClauseWith do
  @moduledoc """
  Interdit les `with` à une seule clause `<-`, avec ou sans `else`.

  Un `with` à une seule branche est toujours remplaçable par un `case`
  (si on veut gérer l'erreur) ou par un simple pattern match.

  Ce check complète `Credo.Check.Readability.WithSingleClause` qui ne
  détecte pas les `with` sans `else`.

  ## Exemple invalide

      # ❌ with à une seule branche sans else
      with {:ok, value} <- do_something() do
        use(value)
      end

      # ❌ with à une seule branche avec else
      with {:ok, value} <- do_something() do
        use(value)
      else
        {:error, reason} -> handle(reason)
      end

  ## Exemples valides

      # ✅ case explicite
      case do_something() do
        {:ok, value} -> use(value)
        {:error, reason} -> handle(reason)
      end

      # ✅ with à plusieurs clauses (légitime)
      with {:ok, a} <- step1(),
           {:ok, b} <- step2(a) do
        use(a, b)
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :readability

  @doc false
  def run(%SourceFile{} = source_file, _params) do
    Credo.Code.prewalk(source_file, &traverse(&1, &2, source_file), [])
  end

  # Match `with` that has exactly one `<-` clause
  defp traverse({:with, meta, args} = ast, issues, source_file) do
    arrow_clauses = count_arrow_clauses(args)

    if arrow_clauses == 1 do
      {ast, [issue_for(source_file, meta[:line]) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _source_file) do
    {ast, issues}
  end

  defp count_arrow_clauses(args) when is_list(args) do
    args
    |> Enum.count(fn
      {:<-, _meta, _args} -> true
      _ -> false
    end)
  end

  defp count_arrow_clauses(_), do: 0

  defp issue_for(source_file, line_no) do
    format_issue(
      source_file,
      message: "`with` à une seule clause `<-` détecté. Utiliser `case` à la place.",
      line_no: line_no
    )
  end
end
