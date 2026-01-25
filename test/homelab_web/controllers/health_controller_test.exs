defmodule HomelabWeb.HealthControllerTest do
  use HomelabWeb.ConnCase, async: true

  test "/health responds with ok status", %{conn: conn} do
    conn = get(conn, ~p"/health")

    assert %{"status" => "ok"} = json_response(conn, 200)
  end
end
