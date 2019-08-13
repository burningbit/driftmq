defmodule DriftMQ.SocketHandler do
    @behaviour :cowboy_websocket

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
        IO.inspect(state, label: "handle")
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

      decode_packet(packet)
      payload = Jason.decode!("{}")
      message = payload["data"]["message"]

      Registry.DriftMQ
      |> Registry.dispatch(state.registry_key, fn(entries) ->
        for {pid, _} <- entries do
          if pid != self() do
            Process.send(pid, message, [])
          end
        end
      end)

      {:reply, {:binary, <<0::size(1)>>}, state}
    end


    defp decode_packet(packet) do
      struct = {%{}, packet}
      |> command()
      |> remaining_length()
      |> protocol_info()
      |> flags()
      |> keepalive()
      |> client_details()
      |> IO.inspect(label: "Decoded values 2")
      struct
    end

    defp command({struct, <<command::little-integer-size(8), remaining::bitstring>>}) do
      {Map.put(struct, :command, command), remaining}
    end

    defp remaining_length({%{command: 16} = struct, packet}) do
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

    defp protocol_info({%{command: 16} = struct, <<protocol_length::big-integer-size(16), protocol_name::binary-size(protocol_length), protocol_version::big-integer-size(8), remaining::bitstring>>}) do
      struct =
        Map.put(struct, :protocol_length, protocol_length)
        |> Map.put(:protocol, protocol_name)
        |> Map.put(:protocol_level, protocol_version)
      {struct, remaining}
    end

    defp flags({%{command: 16} = struct, <<connect_flags::big-integer-size(8), remaining::bitstring>>}) do
      struct =
        Map.put(struct, :connect_flags, connect_flags)
      {struct, remaining}
    end

    defp keepalive({%{command: 16} = struct, <<keepalive::big-integer-size(16), remaining::bitstring>>}) do
      struct =
        Map.put(struct, :keepalive, keepalive)
      {struct, remaining}
    end

    defp client_details({%{command: 16} = struct, <<client_length::big-integer-size(16), client_id::binary-size(client_length), remaining::bitstring>>}) do
      struct =
        Map.put(struct, :client_id, client_id)
      {struct, remaining}
    end

    def websocket_info(info, state) do
        IO.inspect(state, label: "info")

      {:reply, {:text, info}, state}
    end
  end
