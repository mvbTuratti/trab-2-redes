defmodule StateMachine do


  def serve(socket) do
    socket
    |> read_line()
    |> write_line(socket)

    serve(socket)
  end

  defp read_line(socket) do
    case :gen_tcp.recv(socket, 32, 10000) do
      {:ok, packet} ->  parse_packet(packet)
      {:error, _reason} -> "something went wrong"
    end
  end

  defp parse_packet(<<seqnun::binary-size(4), acknum::binary-size(4), checksum::binary-size(4), payload::binary>> = packet) do
    IO.puts("seqnum: #{seqnun} \nacknum: #{acknum}\nchecksum: #{checksum}\npayload:#{payload}")
    packet
  end
  defp parse_packet(packet) do
    IO.puts("entrou aq")
    packet
  end

  defp write_line(line, socket) do
    :gen_tcp.send(socket, line)
  end
end
