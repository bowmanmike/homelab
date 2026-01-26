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

  @impl true
  def start_container(container_id) do
    "/containers/#{container_id}/start"
    |> request(:post)
    |> handle_void_response()
  end

  @impl true
  def stop_container(container_id, opts) do
    params =
      opts
      |> Keyword.get(:timeout)
      |> case do
        nil -> []
        timeout -> [{"t", to_string(timeout)}]
      end

    "/containers/#{container_id}/stop"
    |> request(:post, params: params)
    |> handle_void_response()
  end

  @impl true
  def restart_container(container_id, opts) do
    params =
      opts
      |> Keyword.get(:timeout)
      |> case do
        nil -> []
        timeout -> [{"t", to_string(timeout)}]
      end

    "/containers/#{container_id}/restart"
    |> request(:post, params: params)
    |> handle_void_response()
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
    Application.fetch_env!(:homelab, __MODULE__)
    |> Keyword.fetch!(:socket_path)
  end

  defp docker_api_base_url do
    Application.fetch_env!(:homelab, __MODULE__)
    |> Keyword.fetch!(:base_url)
  end

  defp docker_api_host_header do
    Application.fetch_env!(:homelab, __MODULE__)
    |> Keyword.fetch!(:host_header)
  end

  defp request(path, method, opts \\ [])

  defp request(path, method, opts) do
    Req.request(client(), Keyword.merge([method: method, url: path], opts))
  end

  defp handle_void_response({:ok, %Req.Response{status: status}}) when status in 200..299, do: :ok
  defp handle_void_response({:ok, %Req.Response{status: 304}}), do: :ok

  defp handle_void_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:http_error, status, body}}
  end

  defp handle_void_response({:error, exception}), do: {:error, exception}
end
