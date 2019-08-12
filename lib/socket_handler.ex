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

    def websocket_handle({:binary, data} = conn, state) do
        <<
        val::little-integer-size(8),
        whole_rest::bitstring
        >> = data
        IO.inspect(conn, label: "handle something #{val} #{String.length(whole_rest)}")
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
  
      {:reply, {:text, message}, state}
    end
  
    def websocket_info(info, state) do
        IO.inspect(state, label: "info")

      {:reply, {:text, info}, state}
    end
  end