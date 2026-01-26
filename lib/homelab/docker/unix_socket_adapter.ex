defmodule Homelab.Docker.UnixSocketAdapter do
  @moduledoc """
  Docker adapter that communicates with the Engine API through a mounted UNIX
  domain socket (usually `/var/run/docker.sock`) using Req.
  """

  @behaviour Homelab.Docker.Adapter

  @impl true
  def list_containers(opts) do
    params = [
      {"all", params_all?(opts) |> to_param_boolean()}
    ]

    case Req.get(client(), url: "/containers/json", params: params) do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  defp params_all?(opts) do
    Keyword.get(opts, :all?, false)
  end

  defp to_param_boolean(true), do: "true"
  defp to_param_boolean(false), do: "false"

  defp client do
    socket_path = docker_socket_path()

    req =
      Req.new(
        base_url: docker_api_base_url(),
        unix_socket: socket_path,
        json: true
      )

    Req.Request.put_header(req, "host", docker_api_host_header())
  end

  defp docker_socket_path do
    Application.get_env(:homelab, __MODULE__, [])
    |> Keyword.get(:socket_path, default_socket_path())
  end

  defp default_socket_path do
    System.get_env("DOCKER_SOCKET_PATH", "/var/run/docker.sock")
  end

  defp docker_api_base_url do
    Application.get_env(:homelab, __MODULE__, [])
    |> Keyword.get(:base_url, "http:///v1.41")
  end

  defp docker_api_host_header do
    Application.get_env(:homelab, __MODULE__, [])
    |> Keyword.get(:host_header, "docker")
  end
end
