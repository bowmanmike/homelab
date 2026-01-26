defmodule Homelab.Docker do
  @moduledoc """
  High-level interface for interacting with the Docker Engine API over the
  mounted UNIX socket. All Docker-related UI flows should go through this
  context so we can stub it in tests and evolve the transport layer safely.
  """

  alias Homelab.Docker.{Container, UnixSocketAdapter}

  @type list_result :: {:ok, [Container.t()]} | {:error, term()}

  @doc """
  Returns the list of containers currently known to Docker. By default it only
  returns running containers (`all=false`), mirroring `docker ps`.

  The response is normalized into `Homelab.Docker.Container` structs that expose
  Compose labels as first-class fields.
  """
  @spec list_containers(keyword()) :: list_result
  def list_containers(opts \\ []) do
    with {:ok, raw_containers} <- adapter().list_containers(opts) do
      containers =
        raw_containers
        |> Enum.map(&Container.from_api_map/1)
        |> Enum.sort_by(&sort_key/1)

      {:ok, containers}
    end
  end

  defp adapter do
    config = Application.get_env(:homelab, __MODULE__, [])
    Keyword.get(config, :adapter, default_adapter())
  end

  defp default_adapter, do: UnixSocketAdapter

  defp sort_key(%Container{} = container) do
    {
      container.compose_project || "",
      container.compose_service || "",
      container.name || container.id
    }
  end
end
