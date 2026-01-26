defmodule HomelabWeb.HomeLiveTest do
  use HomelabWeb.ConnCase

  import Phoenix.LiveViewTest

  alias HomelabWeb.HomeLive

  setup :register_and_log_in_user

  test "renders dashboard shell", %{conn: conn, scope: scope} do
    {:ok, view, _html} =
      live_isolated(conn, HomeLive, session: %{"current_scope" => scope})

    assert render(view) =~ "Signed in as"
    assert render(view) =~ "Docker services"
  end
end
