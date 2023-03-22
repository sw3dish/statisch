defmodule Grossglockner do
  def main(_argv) do
    # Expecting content at /content
    IO.puts(File.ls("content"))
  end
end
