defmodule Statisch.TemplateCache do
  def init!() do
    try do
      :ets.new(:template_cache, [:set, :protected, :named_table])
      :ok
    rescue
      e in ArgumentError -> {:error, e.message}
    end
  end

  def insert!(key, val) do
    if :ets.insert_new(:template_cache, {key, val}) do
      val
    else
      raise Statisch.TemplateCacheError, message: "Could not insert template: #{key}"
    end
  end

  def get!(key) do
    case :ets.lookup(:template_cache, key) do
      [val] -> val
      [_ | _] -> raise Statisch.TemplateCacheError, message: "More than one template: #{key}"
      [] -> raise Statisch.TemplateCacheError, message: "No template found: #{key}"
    end
  end
end

defmodule Statisch.TemplateCacheError do
  defexception message: "TemplateCacheError"
end
