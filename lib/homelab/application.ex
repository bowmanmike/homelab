defmodule Homelab.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    maybe_detect_compose_project_name()

    children = [
      HomelabWeb.Telemetry,
      Homelab.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:homelab, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:homelab, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Homelab.PubSub},
      Homelab.Compose.Lock,
      # Start to serve requests, typically the last entry
      HomelabWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Homelab.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HomelabWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_detect_compose_project_name do
    compose_config = Application.get_env(:homelab, Homelab.Compose, [])

    if Keyword.get(compose_config, :project_name) == nil do
      with hostname when is_binary(hostname) <- own_hostname(),
           {:ok, %{"com.docker.compose.project" => project}} when is_binary(project) <-
             Homelab.Docker.UnixSocketAdapter.container_labels(hostname) do
        updated = Keyword.put(compose_config, :project_name, project)
        Application.put_env(:homelab, Homelab.Compose, updated)
      else
        _ -> :ok
      end
    end
  end

  defp own_hostname do
    case System.get_env("HOSTNAME") do
      hostname when is_binary(hostname) ->
        String.trim(hostname)

      nil ->
        case File.read("/etc/hostname") do
          {:ok, contents} -> String.trim(contents)
          {:error, _} -> nil
        end
    end
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
