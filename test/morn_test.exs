defmodule MornTest do
  use ExUnit.Case
  doctest Morn

  test "greets the world" do
    assert Morn.hello() == :world
  end
end
