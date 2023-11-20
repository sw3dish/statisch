defmodule Statisch.File do
  use Ecto.Schema
  import Ecto.Changeset

  alias Statisch.Metadata
  alias Statisch.Utils
  alias Statisch.Template

  embedded_schema do
    field(:path, :string)
    field(:output_path, :string)
    embeds_one(:metadata, Metadata)
    field(:contents, :binary)
  end

  def changeset(file, params \\ %{}) do
    file
    |> cast(params, [:path, :contents, :output_path])
    |> cast_embed(:metadata, required: true)
    |> validate_required([:metadata, :path])
  end

  def new(%__MODULE__{} = params), do: __MODULE__.new(Map.from_struct(params))

  def new(params) do
    case apply_action(changeset(%__MODULE__{}, params), :new) do
      {:error, changeset} -> {:error, Enum.join(Utils.format_changeset_errors(changeset), ", ")}
      {:ok, data} -> {:ok, data}
    end
  end

  def split_contents(file_contents) do
    # TODO: allow the split to be defined
    split_contents = String.split(file_contents, "---%%%---")

    case length(split_contents) do
      # We have 2 instances of the sentinel -- we want what is between
      # the first and second as well as what is after the second
      3 ->
        [_, metadata, contents] = split_contents

        {:ok, {metadata, contents}}

      _ ->
        {:error, "File must have metadata"}
    end
  end

  def build_contents(%__MODULE__{
        metadata: %Metadata{template: template_key} = metadata,
        contents: contents
      }, extra_assigns) do
    {^template_key, template} = Template.get_template!(template_key)
    {:base, base_template} = Template.get_template!(:base)

    assigns = Map.merge(extra_assigns, Map.from_struct(metadata))
    
    # render the inner content
    body = EEx.eval_string(contents, assigns: assigns)
    # render the child template
    assigns = Map.put(assigns, :body,  body)
    inner_content = EEx.eval_string(template, assigns: assigns)
    # place it into the global layout
    assigns = Map.put(assigns, :inner_content, inner_content)
    doc = EEx.eval_string(base_template, assigns: assigns)
    {:ok, doc}
  end

  def get_output_path(%__MODULE__{path: path}, input_dir, output_dir) do
    # Extact the path and the file name, but not extension of the file
    # Examples:
    # ./markdown_files/foo.html
    #   foo
    # ./markdown_files/foo/bar.html
    #   foo/bar
    # ./markdown_files/foo/bar.html.eex
    #   foo/bar
    # ./markdown_files/foo/bar/baz/quuz.html
    #   foo/bar/baz/quuz
    # ./markdown_files/foo/bar/baz/quuz.html.eex
    #   foo/bar/baz/quuz
    path_regex = ~r|#{input_dir}\/(.*?)(?:\.(?:.*))+|
    [_full_match, output_path] = Regex.run(path_regex, path)

    case output_path do
      # Handle root index.html 
      "index" -> {:ok, "#{output_dir}/index.html"}
      # For pretty urls :)
      _ -> {:ok, "#{output_dir}/#{output_path}/index.html"}
    end
  end
end
