defmodule StateMachine do

  use Bitwise

  def serve(socket, ack \\ 0) do
    {msg, ack} = read_line(socket, ack)
    write_line(msg, socket)
    IO.puts("End of message\nWaiting for new one!\n\n################################\n\n")
    serve(socket, ack)
  end

  defp read_line(socket, ack) do
    case :gen_tcp.recv(socket, 32) do
      {:ok, packet} ->
        case check_prob(packet, ack) do
          {:prob, _} -> serve(socket, ack)
          return -> return
        end
      {:error,_packet} -> :gen_tcp.close(socket)
    end
  end

  defp check_prob(packet, ack) do
    prob = String.to_integer(System.get_env("PROB") || "100")
    prob = prob |> min(100) |> max(0)

    num = Enum.random(1..100)
    cond do
      num <= prob ->
        parse_packet(packet, ack)
      num > prob ->
        IO.puts("Packet missed by probability settings!")
        IO.puts("Sending nothing\n\n==========================")
        {:prob, ack}
    end
  end
  defp parse_packet(<<>>, _ack), do: {:error, "probability settings void message"}
  defp parse_packet(<<seqnun::size(4)-unit(8), acknum::size(4)-unit(8), checksum::size(4)-unit(8), payload::size(20)-unit(8)>> = msg, ack) do
    IO.inspect(msg)
    IO.puts("Message received! \n\n")
    IO.puts("sequence number: #{seqnun}\nACK: #{acknum}\nchecksum:\n")
    IO.inspect(<<checksum::size(4)-unit(8)>>)
    IO.puts("payload:")
    IO.inspect(<<payload::size(20)-unit(8)>>)
    <<z, x, y, c>> = <<checksum::size(4)-unit(8)>>
    check_as_bit = [z,x,y,c] |> Enum.map(&(Integer.digits(&1,2) |> correct_bit_to_byte())) |> List.flatten()
    <<a::size(4)-unit(8), b::size(4)-unit(8),d::size(4)-unit(8), e::size(4)-unit(8), f::size(4)-unit(8)>> = <<payload::size(20)-unit(8)>>
    IO.puts("Valor checksum calculado com o payload")

    (a + b + d + e + f)
    |> Integer.digits(2)
    |> Enum.take(-32)
    |> correct_bit_size()
    |> Enum.zip(check_as_bit)
    |> Enum.map(fn {a,b} -> bxor(a,b) end)
    |> Enum.any?(fn x-> x != 1 end)
    |> create_msg(acknum, ack, checksum)

  end

  defp correct_bit_size(list) do
    l = length(list)
    ms = for _ <- 1..32-l, into: [], do: 0
    ms ++ list
  end

  defp correct_bit_to_byte(list) do
    l = length(list)
    ms = for _ <- 1..8-l, into: [], do: 0
    ms ++ list
  end

  defp create_msg(false, _acknum, ack, checksum), do: {<<0,0,0,ack>> <> <<checksum::size(4)-unit(8)>>, ack}
  defp create_msg(true, acknum, ack, checksum) do
    cond do
      acknum == ack ->
        ack = (ack == 1 && 0) || 1  #muda entre 0 e 1, invertendo.
        {<<acknum::size(4)-unit(8)>> <> <<checksum::size(4)-unit(8)>>, ack}
      true ->
        {<<0,0,0,ack>> <> <<checksum::size(4)-unit(8)>>, ack}
    end
  end
  defp write_line(line, socket) do
    :gen_tcp.send(socket, line)
  end
end
