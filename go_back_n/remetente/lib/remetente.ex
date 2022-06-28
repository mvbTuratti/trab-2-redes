defmodule Remetente do
  use GenServer
  use Bitwise

  def start_link() do
    GenServer.start_link(__MODULE__, %{data: nil, socket: nil}, name: Sender)
  end
  def send() do
    GenServer.cast(Sender, :send)
  end


  defp send_message(data, socket) do
    IO.puts("\n===============================\n\nEnvio\n")
    IO.puts("ACK: #{data.ack}\n")
    IO.puts("Dados:\t")
    IO.inspect(data)
    <<a::size(4)-unit(8), b::size(4)-unit(8),d::size(4)-unit(8), e::size(4)-unit(8), f::size(4)-unit(8)>> = <<data.data::size(20)-unit(8)>>
    checksum = a+b+d+e+f
      |> Integer.digits(2)
      |> Enum.take(-32)
      |> correct_bit_size()
      |> Enum.map(&(bxor(&1,1)))
      |> Enum.into(<<>>, fn bit -> <<bit :: 1>> end)
      |> check_helper()

    IO.puts("Checksum:\t")
    IO.inspect(checksum)

    payload = <<data.seqnum::size(4)-unit(8), data.ack::size(4)-unit(8)>>  <> checksum <> <<data.data::size(20)-unit(8)>>
    IO.puts("Mensagem enviada:\n")
    IO.inspect(payload)

    :gen_tcp.send(socket, payload)
  end

  @impl true
  def init(state) do
    {:ok, sock} = :gen_tcp.connect({127,0,0,1}, 4321, [:binary, active: false, packet: :raw])
    {:ok, %{state | data: start_data(0,5), socket: sock}}
  end

  @impl true
  def handle_cast(:send, state) do
    state = send_all(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:resend, state) do
    send_all(state)
    {:noreply, state}
  end

  defp responses(state) do
    with {:ok, msg} <- :gen_tcp.recv(state.socket, 8, 1000),
         {:acked, new_data, new} <- compare_ack(msg, state)
    do
      state = %{state | data: new_data}
      send_message(new, state[:socket])
      responses(state)
    else
      {:error, _} ->
        IO.puts("Timed out response. Retry.\n")
        send_all(state)
      {:missed, message} ->
        IO.puts("\n#{message}\n")
        :timer.send_after(1000, self(), :resend)
        state
    end
  end

  defp correct_bit_size(list) do
    l = length(list)
    ms = for _ <- 1..32-l, into: [], do: 0
    ms ++ list
  end

  defp check_helper(<<_>> = v), do: <<0,0,0>> <> v
  defp check_helper(<<_, _>> = v), do: <<0,0>> <> v
  defp check_helper(<<_,_,_>> = v), do: <<0>> <> v
  defp check_helper(v), do: v

  defp send_all(state) do
    messages = state[:data]
    socket = state[:socket]
    for msg <- messages, do: send_message(msg, socket)
    responses(state)
  end

  defp compare_ack(msg, state) do
    IO.puts("Resposta recebida\n")
    <<d::size(4)-unit(8), _rest::binary>> = msg
    IO.puts("ACK recebido: #{d}\n\n====================================")
    [msg | remainder] = state[:data]
    case msg[:ack] == d || d == 255 do
      true ->
        l = remainder |> List.last()
        new_data = %{l | seqnum: l[:seqnum] + 20, ack: l[:ack] + 1, data: l[:data] + 1}
        {:acked, remainder ++ [new_data], new_data}
      false ->
        IO.inspect(state[:data])
        {:missed, "Ack not correct for the response"}
    end
  end
  defp start_data(x,y), do: for c <- x..y, into: [] , do: %{seqnum: c*20, ack: c, data: c+1}
end
