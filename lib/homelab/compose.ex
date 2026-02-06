defmodule Homelab.Compose do
  @moduledoc """
  High-level interface for Docker Compose operations.

  Provides pull, recreate, and combined update operations for compose-managed
  services. All operations are serialized through a lock to prevent concurrent
  compose commands from racing.
  """

  alias Homelab.Compose.Lock

  @doc """
  Returns true if compose is properly configured and the project directory exists.
  """
  @spec available?() :: boolean()
  def available? do
    case project_dir() do
      nil -> false
      dir -> File.dir?(dir) and has_compose_file?(dir)
    end
  end

  @doc """
  Returns the configured project directory, or nil if not set.
  """
  @spec project_dir() :: String.t() | nil
  def project_dir do
    config = Application.get_env(:homelab, __MODULE__, [])
    Keyword.get(config, :project_dir)
  end

  defp has_compose_file?(dir) do
    File.exists?(Path.join(dir, "docker-compose.yml")) or
      File.exists?(Path.join(dir, "docker-compose.yaml")) or
      File.exists?(Path.join(dir, "compose.yml")) or
      File.exists?(Path.join(dir, "compose.yaml"))
  end

  @type output :: String.t()
  @type error ::
          :lock_busy
          | {:pull_failed, non_neg_integer(), output()}
          | {:up_failed, non_neg_integer(), output()}
          | :timeout
          | term()
  @type result :: {:ok, output()} | {:error, error()}

  @doc """
  Pulls the latest image for a service and recreates the container.

  This is the primary "update" action: it runs `docker compose pull <service>`
  followed by `docker compose up -d --force-recreate <service>`.

  Acquires a lock to prevent concurrent compose operations.
  """
  @spec update_service(map(), String.t()) :: result()
  def update_service(_current_scope, service) when is_binary(service) do
    with_lock(fn ->
      with {:ok, _pull_output} <- do_pull(service),
           {:ok, up_output} <- do_up(service) do
        {:ok, up_output}
      else
        {:error, {:exit, code, output}} ->
          {:error, {:pull_failed, code, output}}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  @doc """
  Pulls latest images and recreates all services in the compose stack.
  """
  @spec update_all(map()) :: result()
  def update_all(_current_scope) do
    with_lock(fn ->
      with {:ok, _pull_output} <- runner().pull_all(),
           {:ok, up_output} <- do_up_all() do
        {:ok, up_output}
      else
        {:error, {:exit, code, output}} ->
          {:error, {:pull_failed, code, output}}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  @doc """
  Pulls the latest image for a service without recreating.

  Useful when you want to stage an update without restarting the service.
  """
  @spec pull_service(map(), String.t()) :: result()
  def pull_service(_current_scope, service) when is_binary(service) do
    with_lock(fn ->
      case do_pull(service) do
        {:ok, output} -> {:ok, output}
        {:error, {:exit, code, output}} -> {:error, {:pull_failed, code, output}}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @doc """
  Recreates a service container without pulling.

  Useful after a pull or when you want to restart with the current image.
  """
  @spec recreate_service(map(), String.t()) :: result()
  def recreate_service(_current_scope, service) when is_binary(service) do
    with_lock(fn ->
      case do_up(service) do
        {:ok, output} -> {:ok, output}
        {:error, {:exit, code, output}} -> {:error, {:up_failed, code, output}}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp with_lock(fun) do
    case Lock.acquire() do
      :ok ->
        try do
          fun.()
        after
          Lock.release()
        end

      {:error, :timeout} ->
        {:error, :lock_busy}
    end
  end

  defp do_pull(service) do
    runner().pull(service)
  end

  defp do_up(service) do
    case runner().up(service) do
      {:ok, output} -> {:ok, output}
      {:error, {:exit, code, output}} -> {:error, {:up_failed, code, output}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_up_all do
    case runner().up_all() do
      {:ok, output} -> {:ok, output}
      {:error, {:exit, code, output}} -> {:error, {:up_failed, code, output}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp runner do
    config = Application.get_env(:homelab, __MODULE__, [])
    Keyword.get(config, :runner, Homelab.Compose.Runner)
  end
end
