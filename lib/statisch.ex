defmodule Statisch do
  alias Statisch.{
    File,
    FileSystem,
    Metadata,
    Template,
    TemplateCache,
    Transformer
  }

  @content_dir "./content"
  @output_dir "./output"
  @template_dir "./templates"
  @base_layout_path "./templates/layouts/base.html.eex"

  def clear_output_dirs() do
    Elixir.File.rm_rf!(@output_dir)
    Elixir.File.mkdir!(@output_dir)
  end

  def load_file(path) do
    with {:ok, contents} <- Elixir.File.read(path),
         {:ok, {metadata_string, content}} <- File.split_contents(contents),
         {:ok, metadata} <- Metadata.parse_from_string(metadata_string),
         {:ok, file} <- File.new(%{metadata: metadata, contents: content, path: path}) do
      {:ok, file}
    else
      {:error, reason} ->
        {:error, "ERROR [loading file] #{path}: #{reason}"}
    end
  end

  def transform_file(%File{path: path} = file) do
    case Transformer.transform_file(file, Path.extname(path)) do
      {:ok, file} ->
        {:ok, file}

      {:error, reason} ->
        {:error, "ERROR [transforming file] #{path}: #{reason}"}
    end
  end

  def write_file(%File{path: path} = file) do
    with {:ok, doc} <- File.build_contents(file),
         {:ok, output_path} <- File.get_output_path(file, "./markdown_files", "./output"),
         :ok <- Elixir.File.mkdir_p(Path.dirname(output_path)),
         :ok <- Elixir.File.write(output_path, doc) do
      {:ok, output_path}
    else
      {:error, reason} ->
        {:error, "ERROR [writing file] #{path}: #{reason}"}
    end
  end

  def process_file(path) do
    with {:ok, %File{path: path} = loaded_file} <- load_file(path),
         {:ok, transformed_file} <- transform_file(loaded_file),
         {:ok, output_path} <- write_file(transformed_file) do
      {:ok, {path, output_path}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def process_files(paths) do
    stream = Task.async_stream(paths, &process_file/1)
    {:ok, Enum.map(stream, fn {:ok, result} -> result end)}
  end

  def report_stats(results) do
    {successes, failures} = Enum.split_with(results, fn {status, _} -> status == :ok end)
    IO.puts("----------------------------")
    IO.puts("-         Statisch         -")
    IO.puts("----------------------------")

    Enum.each(successes, fn {:ok, {input, output}} ->
      IO.puts("#{input} was written to #{output}")
    end)

    IO.puts("----------------------------")

    Enum.each(failures, fn {:error, message} ->
      IO.puts(message)
    end)
  end

  def main(_argv) do
    TemplateCache.init!()

    Template.load_templates!("./markdown_templates")
    |> Template.cache_templates!()

    with {:ok, paths} <- FileSystem.gather_files("./markdown_files"),
         {:ok, results} <- process_files(paths) do
      report_stats(results)
    end
  end
end
