defmodule Homelab.Docker.ContainerTest do
  use ExUnit.Case, async: true

  alias Homelab.Docker.Container

  describe "from_api_map/1" do
    test "normalizes docker payloads into structs" do
      api_map = %{
        "Id" => "abc123456789",
        "Names" => ["/compose-web-1"],
        "Image" => "ghcr.io/example/app:latest",
        "ImageID" => "sha256:deadbeef",
        "State" => "running",
        "Status" => "Up 5 minutes",
        "Created" => 1_700_000_000,
        "Labels" => %{
          "com.docker.compose.project" => "homelab",
          "com.docker.compose.service" => "web",
          "com.docker.compose.container-number" => "1"
        }
      }

      container = Container.from_api_map(api_map)

      assert container.id == "abc123456789"
      assert container.name == "compose-web-1"
      assert container.image == "ghcr.io/example/app:latest"
      assert container.image_id == "sha256:deadbeef"
      assert container.state == "running"
      assert container.status == "Up 5 minutes"
      assert %DateTime{} = container.created_at
      assert container.compose_project == "homelab"
      assert container.compose_service == "web"
      assert container.compose_container_number == "1"
      assert container.labels["com.docker.compose.project"] == "homelab"
    end

    test "handles missing optional fields gracefully" do
      api_map = %{
        "Id" => "xyz",
        "Names" => [],
        "Image" => "redis:7",
        "State" => nil,
        "Status" => "",
        "Created" => "not-a-number",
        "Labels" => %{}
      }

      container = Container.from_api_map(api_map)

      assert container.name == nil
      assert container.image == "redis:7"
      assert container.state == nil
      assert container.status == ""
      assert container.created_at == nil
      assert container.compose_project == nil
    end
  end
end
