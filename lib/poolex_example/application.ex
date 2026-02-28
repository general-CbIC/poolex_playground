defmodule PoolexExample.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PoolexExampleWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:poolex_example, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PoolexExample.PubSub},
      # Start a worker by calling: PoolexExample.Worker.start_link(arg)
      # {PoolexExample.Worker, arg},
      # Start to serve requests, typically the last entry
      PoolexExampleWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PoolexExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PoolexExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
