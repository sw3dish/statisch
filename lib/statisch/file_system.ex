defmodule Statisch.FileSystem do
  def clear_dir(dir, true) do
    File.rm_rf!(dir)
    File.mkdir!(dir)
  end

  def clear_dir(dir, false) do
    File.rmdir!(dir)
  end

  def gather_files(path) do
    try do
      {:ok, __MODULE__.gather_files_fun(path)}
    rescue
      e -> {:error, e.message}
    end
  end

  def gather_files_fun(path) do
    cond do
      File.regular?(path) ->
        [path]

      File.dir?(path) ->
        path
        |> File.ls!()
        |> Enum.map(&Path.join(path, &1))
        |> Enum.flat_map(&gather_files_fun/1)

      true ->
        []
    end
  end
end
