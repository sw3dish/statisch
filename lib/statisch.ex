defmodule Statisch do
  alias Statisch.{
    File,
    FileSystem,
    Metadata,
    Template,
    TemplateCache,
    Transformer
  }

  @input_dir "./content"
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
         {:ok, output_path} <- File.get_output_path(file, @input_dir, @output_dir),
         :ok <- Elixir.File.mkdir_p(Path.dirname(output_path)),
         :ok <- Elixir.File.write(output_path, doc) do
      {:ok, output_path}
    else
      {:error, reason} ->
        {:error, "ERROR [writing file] #{path}: #{reason}"}
    end
  end

  def drop_draft(%File{metadata: %Metadata{draft: true}}), do: {:warn, :dropped}

  def drop_draft(%File{metadata: %Metadata{draft: false}} = file), do: {:ok, file}

  def process_file(path) do
    with {:ok, %File{path: path} = loaded_file} <- load_file(path),
         {:ok, %File{} = non_draft} <- drop_draft(loaded_file),
         {:ok, transformed_file} <- transform_file(non_draft),
         {:ok, output_path} <- write_file(transformed_file) do
      {:ok, {path, output_path}}
    else
      {:warn, :dropped} ->
        {:warn, path}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def process_files(paths) do
    stream = Task.async_stream(paths, &process_file/1)
    {:ok, Enum.map(stream, fn {:ok, result} -> result end)}
  end

  def split_results(results) do
    Enum.reduce(results, {[], [], []}, fn result, {successes, warnings, errors} -> 
      case result do
        {:ok, _} ->
          {[result | successes], warnings, errors}
        {:warn, _} ->
          {successes, [result | warnings], errors}
        {:error, _} ->
          {successes, warnings, [result | errors]}
      end
    end)
  end

  def report_stats({successes, warnings, errors}) do
    IO.puts("----------------------------")
    IO.puts("-         Statisch         -")
    IO.puts("----------------------------")

    Enum.each(successes, fn {:ok, {input, output}} ->
      IO.puts("#{input} was written to #{output}")
    end)
    
    IO.puts("----------------------------")

    Enum.each(warnings, fn {:warn, input} ->
      IO.puts("#{input} was not written due to draft status")
    end)

    IO.puts("----------------------------")

    Enum.each(errors, fn {:error, message} ->
      IO.puts(message)
    end)
  end

  def main(_argv) do
    TemplateCache.init!()
    clear_output_dirs()

    Template.load_templates!(@template_dir)
    |> Template.cache_templates!()

    with {:ok, paths} <- FileSystem.gather_files(@input_dir),
         {:ok, results} <- process_files(paths),
         results <- split_results(results) do
      report_stats(results)
    end
  end
end
