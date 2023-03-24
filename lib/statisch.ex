defmodule Statisch do
  alias Statisch.Metadata

  def main(_argv) do
    gather_markdown_files("./content")
    |> Enum.map(&read_file/1)
    |> Enum.map(&split_file/1)
    |> Enum.map(&parse_metadata/1)
    |> Enum.map(&transform_contents/1)
    |> IO.inspect()

    # inject into template
    # write to file
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

      true ->
        []
    end
  end

  def read_file(path) do
    case File.read(path) do
      {:ok, contents} ->
        {:ok, path, contents}

      {:error, reason} ->
        {:error, path, reason}
    end
  end

  # returns either {:ok, path, {metadata, contents}}
  # or {:error, path, reason}
  def split_file({:ok, path, contents}) do
    split_contents = String.split(contents, "---%%%---")

    case length(split_contents) do
      3 ->
        [_, metadata, contents] = split_contents
        {:ok, path, {metadata, contents}}

      _ ->
        {:error, path, "No metadata found!"}
    end
  end

  def split_file(error = {:error, _, _}), do: error

  def parse_metadata({:ok, path, {metadata, contents}}) do
    case Toml.decode(metadata) do
      {:ok, decoded_metadata} ->
        try do
          new_metadata = Metadata.from_map(decoded_metadata)
          {:ok, path, {new_metadata, contents}}
        rescue
          ArgumentError ->
            {:error, path, "Required metadata fields missing"}
        end

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
