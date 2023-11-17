defmodule Statisch.Metadata do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:title, :string)
    field(:description, :string)
    field(:published_date, :string)
    field(:template, Ecto.Enum, values: [:none, :page, :post], default: :post)
    field(:hide_footer, :boolean, default: false)
    field(:draft, :boolean, default: false)
  end

  def changeset(metadata, params \\ %{})

  def changeset(metadata, %__MODULE__{} = params) do
    changeset(metadata, Map.from_struct(params))
  end

  def changeset(metadata, params) do
    metadata
    |> cast(params, [:title, :description, :published_date, :template, :draft, :hide_footer])
    |> validate_required([:title, :description, :published_date, :template, :draft, :hide_footer])
  end

  def parse_from_string(string) do
    case Toml.decode(string, keys: :atoms) do
      {:error, {:invalid_toml, reason}} ->
        {:error, "Metadata could not be parsed: #{reason}"}

      result ->
        result
    end
  end
end
