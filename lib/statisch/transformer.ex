defmodule Statisch.Transformer do
  alias Statisch.File

  def transform_file(file = %File{contents: nil}, _), do: {:ok, file}

  def transform_file(file = %File{contents: markdown}, ".md") do
    with {:ok, html, _} <- Earmark.as_html(markdown),
         {:ok, new_file} <- File.new(%{file | contents: html}) do
      {:ok, new_file}
    else
      {:error, _, error_messages} ->
        {:error, Enum.join(error_messages, ", ")}

      {:error, message} ->
        {:error, message}
    end
  end

  def transform_file(file = %File{}, _) do
    {:ok, file}
  end
end
