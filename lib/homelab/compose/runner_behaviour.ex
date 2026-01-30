defmodule Homelab.Compose.RunnerBehaviour do
  @moduledoc """
  Behaviour for compose command runners.

  Allows injecting a mock runner in tests.
  """

  @type output :: String.t()
  @type error :: {:exit, non_neg_integer(), output()} | :timeout | term()
  @type result :: {:ok, output()} | {:error, error()}

  @callback pull(service :: String.t()) :: result()
  @callback up(service :: String.t()) :: result()
end
