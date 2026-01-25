defmodule HomelabWeb.HomeLiveTest do
  use HomelabWeb.ConnCase

  import Phoenix.LiveViewTest
  import Homelab.AccountsFixtures

  setup _context do
    tmp = Path.join(System.tmp_dir!(), "home-live-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    reboot_path = Path.join(tmp, "reboot-required")
    uptime_path = Path.join(tmp, "uptime")
    File.write!(uptime_path, "7200.0 0.0")

    previous = Application.get_env(:homelab, Homelab.HostSignals)

    Application.put_env(:homelab, Homelab.HostSignals,
      reboot_required_path: reboot_path,
      uptime_path: uptime_path
    )

    on_exit(fn -> Application.put_env(:homelab, Homelab.HostSignals, previous) end)

    %{reboot_path: reboot_path}
  end

  test "redirects guests to login", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "renders current user info and telemetry when authenticated", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, ~p"/")

    assert html =~ user.email
    assert html =~ "Current time"
    assert html =~ "All clear"
    assert html =~ "Host uptime"
  end

  test "shows reboot required badge when host flag file exists", %{
    conn: conn,
    reboot_path: reboot_path
  } do
    File.write!(reboot_path, "")

    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, ~p"/")

    assert html =~ "Reboot required"
  end
end
