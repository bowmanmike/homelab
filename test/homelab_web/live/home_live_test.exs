defmodule HomelabWeb.HomeLiveTest do
  use HomelabWeb.ConnCase

  import Phoenix.LiveViewTest
  import Homelab.AccountsFixtures

  test "redirects guests to login", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "renders current user info and clock when authenticated", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, ~p"/")

    assert html =~ user.email
    assert html =~ "Current time"
  end
end
