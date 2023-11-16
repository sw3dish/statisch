defmodule Statisch.Template do
  alias Statisch.TemplateCache
  alias Statisch.FileSystem

  def get_template_key(path) do
    # Insert as an atom of the name of the file
    path
    |> Path.basename()
    |> String.split(".")
    |> List.first()
    |> String.to_atom()
  end

  def load_template!(path) do
    try do
      File.read!(path)
    rescue
      File.Error ->
        raise Statisch.TemplateError, message: "Could not load template: #{path}"
    end
  end

  def load_templates!(templates_dir) do
    case FileSystem.gather_files(templates_dir) do
      {:ok, paths} ->
        Enum.map(paths, fn path -> {get_template_key(path), load_template!(path)} end)

      {:error, reason} ->
        raise Statisch.TemplateError, message: "Could not load templates: #{reason}"
    end
  end

  def cache_templates!(templates) do
    Enum.map(templates, fn {key, val} ->
      TemplateCache.insert!(key, val)
    end)
  end

  def get_template!(template) do
    TemplateCache.get!(template)
  end
end

defmodule Statisch.TemplateError do
  defexception message: "TemplateCacheError"
end
