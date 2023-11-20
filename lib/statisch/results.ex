defmodule Statisch.Results do
  alias Statisch.File

  def split(results) do
    Enum.reduce(results, {[], [], []}, fn result, {successes, warnings, errors} ->
      case result do
        {:ok, _} ->
          {[result | successes], warnings, errors}

        {:warn, _} ->
          {successes, [result | warnings], errors}

        {:error, _} ->
          {successes, warnings, [result | errors]}
      end
    end)
  end

  def report({successes, warnings, errors}) do
    IO.puts("----------------------------")
    IO.puts("-         Statisch         -")
    IO.puts("----------------------------")

    Enum.each(successes, fn {:ok, %File{path: path, output_path: output_path}} ->
      IO.puts("#{path} was written to #{output_path}")
    end)

    IO.puts("----------------------------")

    Enum.each(warnings, fn {:warn, input} ->
      IO.puts("#{input} was not written due to draft status")
    end)

    IO.puts("----------------------------")

    Enum.each(errors, fn {:error, message} ->
      IO.puts(message)
    end)
  end
end
