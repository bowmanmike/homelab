defmodule Homelab.Docker.Adapter do
  @moduledoc """
  Behaviour for pluggable Docker Engine API adapters.
  """

  @callback list_containers(keyword()) :: {:ok, [map()]} | {:error, term()}
  @callback start_container(String.t()) :: :ok | {:error, term()}
  @callback stop_container(String.t(), keyword()) :: :ok | {:error, term()}
  @callback restart_container(String.t(), keyword()) :: :ok | {:error, term()}
end
