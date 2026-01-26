defmodule Homelab.DockerTest do
  use ExUnit.Case, async: true

  alias Homelab.Docker
  alias Homelab.Docker.TestAdapter

  setup do
    on_exit(fn -> TestAdapter.reset!() end)
    :ok
  end

  test "list_containers sorts by project, service, name" do
    TestAdapter.set_response(
      {:ok,
       [
         %{
           "Id" => "3",
           "Names" => ["/beta"],
           "Image" => "example/beta:latest",
           "State" => "running",
           "Status" => "Up",
           "Created" => 1_700_000_100,
           "Labels" => %{
             "com.docker.compose.project" => "b",
             "com.docker.compose.service" => "api"
           }
         },
         %{
           "Id" => "1",
           "Names" => ["/alpha"],
           "Image" => "example/alpha:latest",
           "State" => "running",
           "Status" => "Up",
           "Created" => 1_700_000_000,
           "Labels" => %{
             "com.docker.compose.project" => "a",
             "com.docker.compose.service" => "web"
           }
         }
       ]}
    )

    assert {:ok, [first, second]} = Docker.list_containers()
    assert first.compose_project == "a"
    assert second.compose_project == "b"
  end

  test "list_containers forwards adapter errors" do
    TestAdapter.set_response({:error, :econnrefused})

    assert {:error, :econnrefused} = Docker.list_containers()
  end
end
