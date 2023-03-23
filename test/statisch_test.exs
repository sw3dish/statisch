defmodule StatischTest do
  use ExUnit.Case
  doctest Statisch

  test "greets the world" do
    assert Statisch.hello() == :world
  end
end
