defmodule HomelabWeb.HostLive.SignalsTest do
  use HomelabWeb.ConnCase

  import Phoenix.LiveViewTest

  alias HomelabWeb.HostLive.Signals

  setup :register_and_log_in_user

  test "renders host telemetry panel", %{conn: conn, scope: scope} do
    {:ok, view, _html} =
      live_isolated(conn, Signals, session: %{"current_scope" => scope})

    assert render(view) =~ "Reboot status"
    assert has_element?(view, "#dashboard-clock")
  end
end
