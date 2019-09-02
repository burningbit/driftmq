defmodule DriftMQ.SocketHandler do
    use Bitwise
    @behaviour :cowboy_websocket

    @connect 0x10
    @connack 0x20
    @publish 0x30
    @puback 0x40
    @pubrec 0x50
    @pubrel 0x60
    @pubcomp 0x70
    @subscribe 0x80 ||| 0x2
    @suback 0x90
    @unsubscribe 0xA0
    @unsuback 0xB0
    @pingreq 0xC0
    @pingresp 0xD0
    @disconnect 0xE0


    def init(request, _state) do
        IO.inspect(request, label: "Websocket request")
      state = %{registry_key: request.path}
      request = :cowboy_req.set_resp_header("sec-websocket-protocol", "mqtt", request)
      {:cowboy_websocket, request, state}
    end

    def websocket_init(state) do
        IO.inspect(state, label: "Init")
      Registry.DriftMQ
      |> Registry.register(state.registry_key, {})

      {:ok, state}
    end

    def websocket_handle({:text, json}, state) do
      payload = Jason.decode!(json)
      message = payload["data"]["message"]

      Registry.DriftMQ
      |> Registry.dispatch(state.registry_key, fn(entries) ->
        for {pid, _} <- entries do
          if pid != self() do
            Process.send(pid, message, [])
          end
        end
      end)

      {:reply, {:text, message}, state}
    end

    def websocket_handle({:binary, packet}, state) do
      with {command, _} <- decode_packet(packet) do
        {response, state} = command
          |> handle_request(state)
        {:reply, response, state}
      end
    end

    defp handle_request(%{command: @connect} = packet, state) do
      IO.inspect(packet, label: "Connect")
      {
        {
          :binary,
          <<
            @connack::big-integer-size(8),
            2::big-integer-size(8),
            1::big-integer-size(8),
            0::big-integer-size(8)
          >>
        },
        state
      }
    end

    defp handle_request(%{command: @subscribe, payload: payload} = packet, state) do
      IO.inspect(packet, label: "Subscribe")
      {length, more_packet} = remaining_length_accumulate({0, payload}, 1) |> IO.inspect(label: "Subscribe remaining length")
      remaining_length_accumulate({0, more_packet}, 1) |> IO.inspect(label: "Even more packet")
      {
        {
          :binary,
          <<
            @connack::big-integer-size(8),
            2::big-integer-size(8),
            1::big-integer-size(8),
            0::big-integer-size(8)
          >>
        },
        state
      }
    end

    defp handle_request(%{command: @publish} = _packet, state) do
      IO.inspect("Publish")
      {
        {
          :binary,
          <<
            @connack::big-integer-size(8),
            2::big-integer-size(8),
            1::big-integer-size(8),
            0::big-integer-size(8)
          >>
        },
        state
      }
    end

    defp decode_packet(packet) do
      {%{}, packet}
      |> command()
      |> remaining_length()
      |> payload()
    end

    defp command({struct, <<command::little-integer-size(8), remaining::bitstring>>}) do
      {Map.put(struct, :command, command), remaining}
    end

    defp remaining_length({struct, packet}) do
      {remaining_length, remaining} = remaining_length_accumulate({0, packet}, 1)
      {Map.put(struct, :remaining_length, remaining_length), remaining}
    end

    defp remaining_length_accumulate({_current, <<>> = packet}, _multiplier), do: {0, packet}

    defp remaining_length_accumulate({current, <<1::size(1), value::bitstring-size(7), rest::bitstring>>}, multiplier) do
      <<actual_size::little-integer-size(8)>> = <<0::size(1), value::bitstring-size(7)>>
      remaining_length_accumulate({current + multiplier * actual_size, rest}, multiplier * 128)
    end

    defp remaining_length_accumulate({current, <<0::size(1), value::bitstring-size(7), rest::bitstring>>}, multiplier) do
      <<actual_size::little-integer-size(8)>> = <<0::size(1), value::bitstring-size(7)>>
      {current + multiplier * actual_size, rest}
    end

    defp protocol_info({%{command: @connect} = struct, <<protocol_length::big-integer-size(16), protocol_name::binary-size(protocol_length), protocol_version::big-integer-size(8), remaining::bitstring>>}) do
      struct =
        Map.put(struct, :protocol_length, protocol_length)
        |> Map.put(:protocol, protocol_name)
        |> Map.put(:protocol_level, protocol_version)
      {struct, remaining}
    end

    defp flags({%{command: @connect} = struct, <<connect_flags::big-integer-size(8), remaining::bitstring>>}) do
      struct =
        Map.put(struct, :connect_flags, connect_flags)
      {struct, remaining}
    end

    defp keepalive({%{command: @connect} = struct, <<keepalive::big-integer-size(16), remaining::bitstring>>}) do
      struct =
        Map.put(struct, :keepalive, keepalive)
      {struct, remaining}
    end

    defp client_details({%{command: @connect} = struct, <<client_length::big-integer-size(16), client_id::binary-size(client_length), remaining::bitstring>>}) do
      struct =
        Map.put(struct, :client_id, client_id)
      {struct, remaining}
    end

    defp payload({%{remaining_length: _remaining_length} = struct, remaining_packet}) do
      {Map.put(struct, :payload, remaining_packet), <<>>}
      # case remaining_packet do
      #   <<payload::bitstring-size(remaining_length)>> ->
      #   asterisk ->
      #     IO.inspect(asterisk)
      #     :error
      # end
    end

    defp handle_command() do

    end

    def websocket_info(info, state) do
        IO.inspect(state, label: "info")

      {:reply, {:text, info}, state}
    end
  end
