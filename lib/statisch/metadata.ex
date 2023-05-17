defmodule Statisch.Metadata do
  @enforce_keys [:title, :description, :published_date]
  defstruct [
    :title,
    :description,
    :published_date,
    template: "post",
    hide_footer: false
  ]

  def required_keys, do: @enforce_keys
end
