defmodule RemetenteTest do
  use ExUnit.Case
  doctest Remetente

  test "greets the world" do
    assert Remetente.hello() == :world
  end
end
