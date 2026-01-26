defmodule Homelab.Docker.TestAdapter do
  @moduledoc false

  @behaviour Homelab.Docker.Adapter

  def set_responder(responder) when is_function(responder, 1) or is_function(responder, 0) do
    Application.put_env(:homelab, __MODULE__, responder: responder)
    :ok
  end

  def set_response(response) do
    Application.put_env(:homelab, __MODULE__, responder: fn _opts -> response end)
    :ok
  end

  def reset! do
    Application.delete_env(:homelab, __MODULE__)
    :ok
  end

  @impl true
  def list_containers(opts) do
    responder =
      Application.get_env(:homelab, __MODULE__, [])
      |> Keyword.get(:responder, &default_responder/1)

    cond do
      is_function(responder, 1) -> responder.(opts)
      is_function(responder, 0) -> responder.()
      true -> responder
    end
  end

  defp default_responder(_opts), do: {:ok, []}
end
