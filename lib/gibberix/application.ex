defmodule Gibberix.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      GibberixWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Gibberix.PubSub},
      # Start the Endpoint (http/https)
      GibberixWeb.Endpoint
      # Start a worker by calling: Gibberix.Worker.start_link(arg)
      # {Gibberix.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Gibberix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GibberixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
