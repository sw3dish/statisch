defmodule Statisch do
  alias Statisch.{
    File,
    FileSystem,
    Metadata,
    Results,
    Template,
    TemplateCache,
    Transformer
  }

  @input_dir "./content"
  @output_dir "./output"
  @template_dir "./templates"
  @posts_page "#{@input_dir}/posts.html.eex"
  @special_files [@posts_page]

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

  def write_file(%File{path: path} = file, extra_assigns \\ %{}) do
    with {:ok, doc} <- File.build_contents(file, extra_assigns),
         {:ok, output_path} <- File.get_output_path(file, @input_dir, @output_dir),
         :ok <- Elixir.File.mkdir_p(Path.dirname(output_path)),
         :ok <- Elixir.File.write(output_path, doc),
         {:ok, file} <- File.new(%{file | contents: doc, output_path: output_path}) do
      {:ok, file}
    else
      {:error, reason} ->
        {:error, "ERROR [writing file] #{path}: #{reason}"}
    end
  end

  def process_file(path, extra_assigns \\ %{}) do
    with {:ok, %File{metadata: %Metadata{draft: false}} = loaded_file} <- load_file(path),
         {:ok, %File{} = transformed_file} <- transform_file(loaded_file),
         {:ok, %File{} = file} <- write_file(transformed_file, extra_assigns) do
      {:ok, file}
    else
      {:ok, %File{metadata: %Metadata{draft: true}}} ->
        {:warn, path}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def process_files(paths) do
    stream = Task.async_stream(paths, &process_file/1)
    {:ok, Enum.map(stream, fn {:ok, result} -> result end)}
  end

  def create_posts_page({successes, _, _}, output_dir) do
    # If there are posts under a `posts` directory,
    # create a page using posts.html.eex
    # that has a listing of all of them by time published
    posts =
      successes
      |> Enum.map(&elem(&1, 1))
      |> Enum.filter(fn file ->
        Regex.match?(~r|#{output_dir}/posts/(.*)|, file.output_path)
      end)
      |> Enum.sort_by(
        fn %File{metadata: %Metadata{published_date: published_date}} ->
          Date.from_iso8601!(published_date)
        end,
        {:desc, Date}
      )
    process_file(@posts_page, %{posts: posts})
    :ok
  end

  def main(_argv) do
    TemplateCache.init!()
    clear_output_dirs()

    Template.load_templates!(@template_dir)
    |> Template.cache_templates!()

    with {:ok, paths} <- FileSystem.gather_files(@input_dir, @special_files),
         {:ok, results} <- process_files(paths),
         results <- Results.split(results),
         :ok <- create_posts_page(results, @output_dir) do
      Results.report(results)
    end
  end
end
