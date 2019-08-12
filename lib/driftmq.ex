defmodule DriftMQ do
  @moduledoc """
  Documentation for DriftMQ.
  """
  use Application

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: DriftMQ.Router,
        options: [
          dispatch: dispatch(),
          port: 4000
        ]
      ),
      Registry.child_spec(
        keys: :duplicate,
        name: Registry.DriftMQ
      )
    ]

    opts = [strategy: :one_for_one, name: DriftMQ.Application]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
        [
          {"/ws/[...]", DriftMQ.SocketHandler, []},
          {:_, Plug.Cowboy.Handler, {DriftMQ.Router, []}}
        ]
      }
    ]
  end
end
