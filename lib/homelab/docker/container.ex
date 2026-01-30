defmodule Homelab.Docker.Container do
  @moduledoc """
  Normalized representation of a Docker container returned by the Engine API.
  """

  @enforce_keys [:id, :image, :state, :status, :created_at]
  defstruct [
    :id,
    :name,
    :image,
    :image_id,
    :state,
    :status,
    :created_at,
    :labels,
    :compose_project,
    :compose_service,
    :compose_container_number,
    :compose_config_files,
    :compose_working_dir
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t() | nil,
          image: String.t(),
          image_id: String.t() | nil,
          state: String.t(),
          status: String.t(),
          created_at: DateTime.t() | nil,
          labels: map(),
          compose_project: String.t() | nil,
          compose_service: String.t() | nil,
          compose_container_number: String.t() | nil,
          compose_config_files: String.t() | nil,
          compose_working_dir: String.t() | nil
        }

  @compose_project_label "com.docker.compose.project"
  @compose_service_label "com.docker.compose.service"
  @compose_container_number_label "com.docker.compose.container-number"
  @compose_config_files_label "com.docker.compose.project.config_files"
  @compose_working_dir_label "com.docker.compose.project.working_dir"

  @doc """
  Converts the JSON map returned by `/containers/json` into a container struct.
  """
  @spec from_api_map(map()) :: t()
  def from_api_map(map) when is_map(map) do
    labels = Map.get(map, "Labels") || %{}

    %__MODULE__{
      id: Map.fetch!(map, "Id"),
      name: normalize_name(Map.get(map, "Names")),
      image: Map.get(map, "Image"),
      image_id: Map.get(map, "ImageID"),
      state: Map.get(map, "State"),
      status: Map.get(map, "Status"),
      created_at: unix_to_datetime(Map.get(map, "Created")),
      labels: labels,
      compose_project: Map.get(labels, @compose_project_label),
      compose_service: Map.get(labels, @compose_service_label),
      compose_container_number: Map.get(labels, @compose_container_number_label),
      compose_config_files: Map.get(labels, @compose_config_files_label),
      compose_working_dir: Map.get(labels, @compose_working_dir_label)
    }
  end

  defp normalize_name([first | _]) when is_binary(first) do
    String.trim_leading(first, "/")
  end

  defp normalize_name(_), do: nil

  defp unix_to_datetime(value) when is_integer(value) or is_float(value) do
    value
    |> trunc()
    |> DateTime.from_unix()
    |> case do
      {:ok, datetime} -> datetime
      _ -> nil
    end
  end

  defp unix_to_datetime(_), do: nil
end
