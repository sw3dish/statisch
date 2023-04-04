defmodule Statisch.Metadata do
  @enforce_keys [:title]
  defstruct [
    :title,
    template: "post"
  ]

  def required_keys, do: @enforce_keys
end
