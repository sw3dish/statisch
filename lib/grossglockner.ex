defmodule Grossglockner do
  def main(_argv) do
    gather_markdown_files("./content")
    |> Enum.map(&split_file/1)
    |> Enum.map(&parse_metadata/1)
    |> Enum.map(&transform_contents/1)
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

  # returns either {:ok, path, {metadata, contents}}
  # or {:error, path, reason}
  def split_file(path) do
    with {ok, contents} <- File.read(path),
         split_contents <- String.split(contents, "---%%%---"),
         length <- String.length(split_contents)
    do
      case length do
        3 ->
          {:ok, path, {split_contents[1], split_contents[2]}}
        _ ->
          {:error, path, "No metadata found!"}
      end
    else
      err -> err
    end
  end

  def parse_metadata({:ok, path, {metadata, contents}}) do
    case JSON.decode(metadata) do
      {:ok, json_decoded_metadata} ->
        {:ok, path, {json_decoded_metadata, contents}}
      {:error, reason} ->
        {:error, path, reason}
    end
  end
  def parse_metadata(error = {:error, _, _}), do: error

  def transform_contents({:ok, path, {metadata, contents}}) do
    case Earmark.as_html(contents) do
      {:ok, html_doc, _} ->
        {:ok, path, {metadata, html_doc}}
      {:error, _html_doc, error_messages} ->
        {:error, path, error_messages}
    end
  end
  def transform_contents(error = {:error, _, _}), do: error
end
