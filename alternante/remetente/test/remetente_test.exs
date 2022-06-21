defmodule RemetenteTest do
  use ExUnit.Case


  test "try to connect" do
    assert {:ok, msg} = Remetente.start_link()
  end

  test "try" do
    {f, pid} = Remetente.start_link()
    assert f = :ok
    Remetente.flip(pid)
    Remetente.flip(pid)
    Remetente.flip(pid)
    IO.puts("yep")
    Remetente.flip(pid)
    Remetente.flip(pid)
    Remetente.flip(pid)
    Remetente.flip(pid)
    Remetente.flip(pid)
    Remetente.flip(pid)
    Remetente.flip(pid)
    Remetente.flip(pid)
    assert true
  end
end
