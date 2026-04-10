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
    needs_project = Keyword.get(compose_config, :project_name) == nil
    needs_service = Keyword.get(compose_config, :self_service) == nil

    if needs_project or needs_service do
      with hostname when is_binary(hostname) <- own_hostname(),
           {:ok, labels} <- Homelab.Docker.UnixSocketAdapter.container_labels(hostname) do
        updated =
          compose_config
          |> maybe_put(:project_name, needs_project, labels["com.docker.compose.project"])
          |> maybe_put(:self_service, needs_service, labels["com.docker.compose.service"])

        Application.put_env(:homelab, Homelab.Compose, updated)
      else
        _ -> :ok
      end
    end
  end

  defp maybe_put(config, _key, false, _value), do: config
  defp maybe_put(config, _key, _needed, nil), do: config
  defp maybe_put(config, key, true, value), do: Keyword.put(config, key, value)

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
