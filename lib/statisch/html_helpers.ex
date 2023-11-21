defmodule Statisch.HTMLHelpers do
  @output_dir "./output"
  def get_url(output_path) do
    url_regex = ~r|#{@output_dir}(\/.*)\/index.html|

    case Regex.run(url_regex, output_path) do
      nil -> "/"
      [_full_match, url] -> url
    end
  end
end
