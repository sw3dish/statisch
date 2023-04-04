defmodule Statisch.Template do
  defmacro include(child_path, assigns) do
    template = File.read!(child_path)
    quote do
      EEx.eval_string(unquote(template), assigns: unquote(assigns))
    end
  end

  defmacro extends(parent_path, assigns, do: block) do
    quote do
      blocks = unquote(assigns)
               |> Map.get(:__blocks__, %{})
      parent_template = File.read!(unquote(parent_path))
      parent_contents = EEx.eval_string(unquote(parent_template), assigns: assigns)

      EEx.eval_string(unquote(parent_contents), assigns: Map.put(assigns, :__blocks__, blocks))
    end
  end

  defmacro block(block_name, assigns) do
    quote do
      blocks = unquote(assigns)
               |> Map.get(:__blocks__, %{})
      case Map.fetch(blocks, unquote(block_name)) do
        {:ok, contents} -> contents
        :error -> raise "Block not found! #{block}"
      end
    end
  end

  defmacro block(block_name, assigns, do: block) do
    quote do
      blocks = unquote(assigns)
               |> Map.get(:__blocks__, %{})
      put_in(assigns, [:__blocks__, unquote(block_name)], unquote(block))
    end
  end
end
