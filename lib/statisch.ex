defmodule Statisch do
  alias Statisch.Metadata

  @content_dir "./content"
  @output_dir "./output"
  @template_dir "./templates"
  @base_layout_path "./templates/layouts/base.html.eex"

  def main(_argv) do
    gather_markdown_files(@content_dir)
    |> Enum.map(&read_file/1)
    |> Enum.map(&split_file/1)
    |> Enum.map(&parse_metadata/1)
    |> Enum.map(&transform_contents/1)
    |> Enum.map_reduce(initialize_template_cache(), &inject_into_template/2)
    |> drop_cache()
    |> Enum.map(&write_file/1)
    # inject into template
    # write to file
    |> IO.inspect()
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
    case Toml.decode(metadata, keys: :atoms) do
      {:ok, decoded_metadata} ->
        # Add any default keys to Metadata
        try do
          new_metadata = struct!(Metadata, decoded_metadata)
          {:ok, path, {new_metadata, contents}}
        rescue
          ArgumentError ->
            missing_fields = Metadata.required_keys() -- Map.keys(decoded_metadata)
            missing_fields_string = Enum.map_join(missing_fields, ", ", &Atom.to_string/1)
            {:error, path, "Required metadata fields missing: #{missing_fields_string}"}
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

  def inject_into_template({:ok, path, {metadata, contents}}, cache) do
    template_name = metadata.template

    case put_into_cache(cache, template_name) do
      {:ok, cache} ->
        assigns = %{
          body: contents,
          title: metadata.title
        }

        # render the inner content
        inner_content = EEx.eval_string(cache[template_name], assigns: assigns)
        # place it into the global layout
        assigns = Map.put(assigns, :inner_content, inner_content)
        doc = EEx.eval_string(cache[:base], assigns: assigns)

        {{:ok, path, {metadata, doc}}, cache}

      {:error, _reason} ->
        {{:error, path, "Could not open #{template_name}.eex for reading!"}, cache}
    end
  end

  def inject_into_template(error = {:error, _, _}, cache), do: {error, cache}

  def put_into_cache(cache, template_name) do
    template_path = Path.join(@template_dir, "#{template_name}.eex")

    case Map.get(cache, template_name) do
      # if we can't find the template in the cache, add it
      nil ->
        case File.read(template_path) do
          {:ok, contents} ->
            cache = Map.put(cache, template_name, contents)
            {:ok, cache}

          error ->
            error
        end

      # if we can, pass the cache back so we can access later
      _ ->
        {:ok, cache}
    end
  end

  def drop_cache({results, _cache = %{}}) do
    results
  end

  def write_file({:ok, path, {metadata, contents}}) do
    trimmed_path =
      path
      |> String.trim_leading(@content_dir)
      |> String.trim_trailing(".md")

    output_path = Path.join(@output_dir, "#{trimmed_path}.html")

    with :ok <- File.mkdir_p(Path.dirname(output_path)),
         :ok <- File.write(output_path, contents) do
      {:ok, path, {metadata, contents}}
    else
      {:error, _reason} ->
        {:error, path, "Could not write to file #{output_path}"}
    end
  end

  def write_file(error = {:error, _, _}), do: error

  def initialize_template_cache() do
    base = File.read!(@base_layout_path)

    %{
      base: base
    }
  end
end
