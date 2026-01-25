defmodule HomelabWeb.LandingControllerTest do
  use HomelabWeb.ConnCase

  import Homelab.AccountsFixtures

  test "anonymous users see login view", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert html_response(conn, 200) =~ "Log in"
    assert conn.resp_body =~ "Access is invite-only"
  end

  test "signed in users see dashboard", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    conn = get(conn, ~p"/")

    body = html_response(conn, 200)
    assert body =~ user.email
    assert body =~ "Reboot status"
  end
end
