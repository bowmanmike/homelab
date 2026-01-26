defmodule Homelab.Docker.TestAdapter do
  @moduledoc false

  @behaviour Homelab.Docker.Adapter

  def reset! do
    Application.delete_env(:homelab, __MODULE__)
    :ok
  end

  def set_list_responder(responder) when is_function(responder, 1) do
    put(:list, responder)
  end

  def set_list_response(response) do
    put(:list, fn _opts -> response end)
  end

  def set_start_response(response) do
    put(:start, response)
  end

  def set_stop_response(response), do: put(:stop, response)
  def set_restart_response(response), do: put(:restart, response)
  def set_pull_response(response), do: put(:pull, response)

  @impl true
  def list_containers(opts) do
    exec(:list, fn _opts -> {:ok, []} end, opts)
  end

  @impl true
  def start_container(container_id) do
    exec(:start, :ok, container_id)
  end

  @impl true
  def stop_container(container_id, _opts), do: exec(:stop, :ok, container_id)

  @impl true
  def restart_container(container_id, _opts), do: exec(:restart, :ok, container_id)

  @impl true
  def pull_image(image), do: exec(:pull, :ok, image)

  defp exec(key, default, arg) do
    responder =
      Application.get_env(:homelab, __MODULE__, %{})
      |> Map.get(key, default)

    cond do
      is_function(responder, 1) -> responder.(arg)
      is_function(responder, 0) -> responder.()
      true -> responder
    end
  end

  defp put(key, value) do
    config = Application.get_env(:homelab, __MODULE__, %{})
    Application.put_env(:homelab, __MODULE__, Map.put(config, key, value))
    :ok
  end
end
