defmodule StateMachine do

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
  defp parse_packet(<<seqnun::size(4)-unit(8), acknum::size(4)-unit(8), checksum::size(4)-unit(8), payload::binary>>, ack) do
    IO.puts("Message received! \n\n")
    IO.puts("sequence number: #{seqnun}\nACK: #{acknum}\nchecksum: #{checksum}\npayload:")
    IO.inspect(payload)
    cond do
      acknum == ack ->
        ack = (ack == 1 && 0) || 1  #muda entre 0 e 1, invertendo.
        {<<acknum::size(4)-unit(8)>> <> <<checksum::size(4)-unit(8)>>, ack}
      true ->
        {<<0,0,0,ack>> <> <<0::size(4)-unit(8)>>, ack}
    end
  end

  defp write_line(line, socket) do
    :gen_tcp.send(socket, line)
  end
end
