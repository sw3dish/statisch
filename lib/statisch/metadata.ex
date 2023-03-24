defmodule Statisch.Metadata do
  @enforce_keys [:title]
  defstruct [
    :title,
    template: "post",
  ]

  def required_keys, do: @enforce_keys

  def from_map(map) do
    map_with_atom_keys = for {key, val} <- map, into: %{} do
      {String.to_existing_atom(key), val}
    end
    struct!(__MODULE__, map_with_atom_keys)
  end
end
