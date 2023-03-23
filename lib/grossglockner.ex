defmodule Grossglockner do
  def main(_argv) do
    gather_markdown_files("./content")
  end

  def gather_markdown_files(path) do
    cond do
      File.regular?(path) ->
        case Path.extname(path) do
          ".md" -> [path]
          _ -> []
        end
      File.dir?(path) ->
        case File.ls(path) do
          {:ok, paths} ->
            paths
            |> Enum.map(&Path.join(path, &1))
            |> Enum.flat_map(&gather_markdown_files/1)
          {:error, reason} ->
            IO.puts("Could not build #{path}: #{reason}")
        end
      true -> []
    end
  end
end
