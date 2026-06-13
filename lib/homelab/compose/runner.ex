defmodule Homelab.Compose.Runner do
  @moduledoc """
  Executes docker compose CLI commands with validation and timeouts.

  All user-provided input (service names) is validated before being passed
  to System.cmd. Commands run with a Task wrapper to enforce timeouts.
  """

  @behaviour Homelab.Compose.RunnerBehaviour

  @valid_service_name_regex ~r/^[a-zA-Z0-9_-]+$/

  @impl true
  def pull(service) do
    service = validate_service_name!(service)
    run_compose(["pull", service])
  end

  @impl true
  def pull_all do
    case other_services() do
      [] -> run_compose(["pull"])
      services -> run_compose(["pull"] ++ services)
    end
  end

  # `--wait` blocks until the recreated container is running (and healthy, if it
  # defines a healthcheck) before the command returns, so a reported success
  # reflects the new container actually being up rather than just created.
  @up_args ["up", "-d", "--force-recreate", "--wait"]

  @impl true
  def up(service) do
    service = validate_service_name!(service)
    run_compose(@up_args ++ [service])
  end

  @impl true
  def up_all do
    case other_services() do
      [] -> run_compose(@up_args)
      services -> run_compose(@up_args ++ services)
    end
  end

  @doc """
  Validates a service name contains only safe characters.

  Raises `ArgumentError` if the name is invalid.
  """
  @spec validate_service_name!(String.t()) :: String.t()
  def validate_service_name!(name) when is_binary(name) do
    if Regex.match?(@valid_service_name_regex, name) do
      name
    else
      raise ArgumentError, "invalid service name: #{inspect(name)}"
    end
  end

  def validate_service_name!(name) do
    raise ArgumentError, "service name must be a string, got: #{inspect(name)}"
  end

  defp run_compose(args) do
    timeout = command_timeout()
    project_dir = project_dir()

    project_name_args =
      case project_name() do
        nil -> []
        name -> ["--project-name", name]
      end

    env_file_args =
      case File.exists?(Path.join(project_dir, ".env")) do
        true -> ["--env-file", Path.join(project_dir, ".env")]
        false -> []
      end

    full_args =
      ["compose", "--project-directory", project_dir] ++
        project_name_args ++ env_file_args ++ args

    require Logger
    Logger.info("Running: docker #{Enum.join(full_args, " ")}")

    task =
      Task.async(fn ->
        System.cmd("docker", full_args, stderr_to_stdout: true)
      end)

    result =
      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, {output, 0}} ->
          Logger.info("Compose command succeeded: #{String.slice(output, 0, 200)}")
          {:ok, output}

        {:ok, {output, exit_code}} ->
          Logger.error("Compose command failed (exit #{exit_code}): #{output}")
          {:error, {:exit, exit_code, output}}

        nil ->
          Logger.error("Compose command timed out")
          {:error, :timeout}
      end

    result
  end

  defp project_dir do
    Application.fetch_env!(:homelab, Homelab.Compose)
    |> Keyword.fetch!(:project_dir)
  end

  defp project_name do
    Application.fetch_env!(:homelab, Homelab.Compose)
    |> Keyword.get(:project_name)
  end

  defp self_service do
    Application.fetch_env!(:homelab, Homelab.Compose)
    |> Keyword.get(:self_service)
  end

  defp other_services do
    case {self_service(), list_services()} do
      {nil, _} -> []
      {_, {:error, _}} -> []
      {self, {:ok, services}} -> Enum.reject(services, &(&1 == self))
    end
  end

  defp list_services do
    case run_compose(["config", "--services"]) do
      {:ok, output} ->
        services =
          output
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&Regex.match?(@valid_service_name_regex, &1))

        {:ok, services}

      error ->
        error
    end
  end

  defp command_timeout do
    Application.fetch_env!(:homelab, Homelab.Compose)
    |> Keyword.get(:command_timeout, 120_000)
  end
end
