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

  test "renders container cards when adapter succeeds", %{conn: conn, scope: scope} do
    container = %{
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

    TestAdapter.set_response({:ok, [container]})

    {:ok, view, _html} =
      live_isolated(conn, Services, session: %{"current_scope" => scope})

    assert has_element?(view, "#service-abc123")
    assert render(view) =~ "ghcr.io/example/control:latest"
    assert render(view) =~ "homelab"
  end

  test "shows error badge when adapter returns error", %{conn: conn, scope: scope} do
    TestAdapter.set_response({:error, :econnrefused})

    {:ok, view, _html} =
      live_isolated(conn, Services, session: %{"current_scope" => scope})

    assert render(view) =~ "econnrefused"
    refute render(view) =~ "All systems reachable"
  end
end
