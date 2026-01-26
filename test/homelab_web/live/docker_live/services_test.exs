defmodule HomelabWeb.DockerLive.ServicesTest do
  use HomelabWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Homelab.Docker.TestAdapter
  alias HomelabWeb.DockerLive.Services

  setup do
    on_exit(fn -> TestAdapter.reset!() end)
    :ok
  end

  setup :register_and_log_in_user

  defp container_fixture(opts \\ []) do
    defaults = %{
      "Id" => "abc123",
      "Names" => ["/homelab-web-1"],
      "Image" => "ghcr.io/example/control:latest",
      "State" => "running",
      "Status" => "Up 10 minutes",
      "Created" => 1_700_000_000,
      "Labels" => %{
        "com.docker.compose.project" => "homelab",
        "com.docker.compose.service" => "web"
      }
    }

    Map.merge(defaults, opts)
  end

  test "renders container cards when adapter succeeds", %{conn: conn, scope: scope} do
    TestAdapter.set_list_response({:ok, [container_fixture()]})

    {:ok, view, _html} =
      live_isolated(conn, Services, session: %{"current_scope" => scope})

    assert has_element?(view, "#service-abc123")
    assert render(view) =~ "ghcr.io/example/control:latest"
    assert render(view) =~ "homelab"
  end

  test "shows error badge when adapter returns error", %{conn: conn, scope: scope} do
    TestAdapter.set_list_response({:error, :econnrefused})

    {:ok, view, _html} =
      live_isolated(conn, Services, session: %{"current_scope" => scope})

    assert render(view) =~ "econnrefused"
    refute render(view) =~ "All systems reachable"
  end

  test "starting a container updates command status", %{conn: conn, scope: scope} do
    TestAdapter.set_list_response({:ok, [container_fixture(%{"State" => "exited"})]})
    TestAdapter.set_start_response(:ok)

    {:ok, view, _html} =
      live_isolated(conn, Services, session: %{"current_scope" => scope})

    view
    |> element("#start-abc123")
    |> render_click()

    assert render(view) =~ "homelab-web-1 started."
  end

  test "stopping a container surfaces adapter errors", %{conn: conn, scope: scope} do
    TestAdapter.set_list_response({:ok, [container_fixture()]})
    TestAdapter.set_stop_response({:error, :forbidden})

    {:ok, view, _html} =
      live_isolated(conn, Services, session: %{"current_scope" => scope})

    view
    |> element("#stop-abc123")
    |> render_click()

    assert render(view) =~ "forbidden"
  end

  test "restart button disabled when container not running", %{conn: conn, scope: scope} do
    TestAdapter.set_list_response({:ok, [container_fixture(%{"State" => "exited"})]})

    {:ok, view, _html} =
      live_isolated(conn, Services, session: %{"current_scope" => scope})

    assert view |> element("#restart-abc123[disabled]") |> has_element?()
  end

  test "restart action shows success toast", %{conn: conn, scope: scope} do
    TestAdapter.set_list_response({:ok, [container_fixture()]})
    TestAdapter.set_restart_response(:ok)

    {:ok, view, _html} =
      live_isolated(conn, Services, session: %{"current_scope" => scope})

    view
    |> element("#restart-abc123")
    |> render_click()

    assert render(view) =~ "homelab-web-1 restarted."
  end
end
