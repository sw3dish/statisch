defmodule Statisch.Utils do
  alias Ecto.Changeset

  def format_error({field, sub_errors}) when is_map(sub_errors) do
    ".#{field}#{Enum.map(sub_errors, &format_error/1)}"
  end

  def format_error({field, errs}) when is_list(errs) do
    ".#{field} #{Enum.join(errs, ", ")}"
  end

  def format_changeset_errors(%Changeset{valid?: false} = changeset) do
    errors =
      Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r|%{(\w+)}|, msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    Enum.map(errors, &format_error/1)
  end
end
