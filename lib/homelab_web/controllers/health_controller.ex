defmodule HomelabWeb.HealthController do
  use HomelabWeb, :controller

  alias Homelab.Repo

  def index(conn, _params) do
    Repo.query!("SELECT 1")

    json(conn, %{status: "ok"})
  end
end
