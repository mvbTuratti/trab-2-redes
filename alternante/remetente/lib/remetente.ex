defmodule Remetente do
  use GenStateMachine, callback_mode: [:handle_event_function, :state_enter]
  use Bitwise
  # Client

  def start_link() do
    {:ok, sock} = :gen_tcp.connect({127,0,0,1}, 4321, [:binary, active: false, packet: :raw])
    GenStateMachine.start_link(Remetente, {:off, %{seqnum: 0, ack: 0, data: 0, socket: sock}})
  end

  def flip(pid) do
    GenStateMachine.cast(pid, :flip)
  end

  def get_count(pid) do
    GenStateMachine.call(pid, :get_count)
  end

  # Server (callbacks)

  def handle_event(:enter, _event, state, data) do
    IO.puts("Dados atuais:\n")
    IO.inspect(data)
    {:next_state, state, data}
  end

  def handle_event(:cast, :flip, :off, data) do
    check_message(data, :off)
  end

  def handle_event(:cast, :flip, :on, data) do
    check_message(data, :on)
  end

  def handle_event({:call, from}, :get_count, state, data) do
    {:next_state, state, data, [{:reply, from, data}]}
  end

  def handle_event(event_type, event_content, state, data) do
    # Call the default implementation from GenStateMachine
    super(event_type, event_content, state, data)
  end

  defp send_message(data) do
    IO.puts("\n===============================\n\nEnvio\n")
    IO.puts("ACK: #{data.ack}\n")
    IO.puts("Dados:\t")
    IO.inspect(data)
    <<a::size(4)-unit(8), b::size(4)-unit(8),d::size(4)-unit(8), e::size(4)-unit(8), f::size(4)-unit(8)>> = <<data.data::size(20)-unit(8)>>
    checksum = a+b+d+e+f
      |> Integer.digits(2)
      |> Enum.take(-4)
      |> Enum.map(&(bxor(&1,1)))
      |> Enum.reduce(<<>>, fn x, acc -> acc <> <<x::size(1)-unit(8)>> end)
      |> check_helper()

    IO.puts("Checksum:\t")
    IO.inspect(checksum)

    payload = <<data.seqnum::size(4)-unit(8), data.ack::size(4)-unit(8)>>  <> checksum <> <<data.data::size(20)-unit(8)>>
    IO.puts("Mensagem enviada:\n")
    IO.inspect(payload)
    :gen_tcp.send(data.socket, payload)
  end

  defp check_message(data, state) do
    send_message(data)
    with {:ok, msg} <- :gen_tcp.recv(data.socket, 8, 1000)
    do
      IO.puts("Resposta recebida\n")
      <<d::size(4)-unit(8), _rest::binary>> = msg
      IO.puts("ACK recebido: #{d}\n\n====================================")
      case state do
        :off -> {:next_state, :on, %{data | seqnum: data.seqnum + 20, data: data.data + 1, ack: 1}}
        :on -> {:next_state, :off, %{data | seqnum: data.seqnum + 20, data: data.data + 1, ack: 0}}
      end
    else
      {:error, _} ->
        IO.puts("Timed out response. Retry.\n")
        check_message(data,state)
    end
  end

  defp check_helper(<<_>> = v), do: <<0,0,0>> <> v
  defp check_helper(<<_, _>> = v), do: <<0,0>> <> v
  defp check_helper(<<_,_,_>> = v), do: <<0>> <> v
  defp check_helper(v), do: v
end
