defmodule Homelab.Docker.Adapter do
  @moduledoc """
  Behaviour for pluggable Docker Engine API adapters.
  """

  @callback list_containers(keyword()) :: {:ok, [map()]} | {:error, term()}
end
