defmodule Homelab.ComposeTest do
  # async: false because we swap the configured runner and rely on the
  # singleton compose lock / task supervisor from the application tree.
  use ExUnit.Case, async: false

  alias Homelab.Compose

  @listener :compose_test_listener

  # Runner double that reports each call to the registered test process and can
  # be made slow, so we can kill the caller while an `up` is in flight.
  defmodule RecordingRunner do
    @behaviour Homelab.Compose.RunnerBehaviour

    @impl true
    def pull(service) do
      notify({:pull, service})
      {:ok, "pulled #{service}"}
    end

    @impl true
    def pull_all do
      notify(:pull_all)
      {:ok, "pulled all"}
    end

    @impl true
    def up(service) do
      # Simulate the time docker spends stopping the old container and starting
      # the new one — the window during which the caller's connection drops.
      Process.sleep(200)
      notify({:up, service})
      {:ok, "upped #{service}"}
    end

    @impl true
    def up_all do
      Process.sleep(200)
      notify(:up_all)
      {:ok, "upped all"}
    end

    defp notify(message) do
      case Process.whereis(:compose_test_listener) do
        nil -> :ok
        pid -> send(pid, message)
      end
    end
  end

  setup do
    Process.register(self(), @listener)

    previous = Application.get_env(:homelab, Homelab.Compose, [])

    Application.put_env(
      :homelab,
      Homelab.Compose,
      Keyword.put(previous, :runner, RecordingRunner)
    )

    on_exit(fn ->
      Application.put_env(:homelab, Homelab.Compose, previous)
    end)

    :ok
  end

  test "update_service pulls then recreates and returns the up output" do
    assert {:ok, "upped web"} = Compose.update_service(%{}, "web")

    assert_receive {:pull, "web"}
    assert_receive {:up, "web"}
  end

  test "the recreate finishes even when the caller dies mid-operation" do
    # The RecordingRunner runs inside the detached task and reports back to the
    # registered listener (this test process), regardless of who the caller is.
    caller = spawn(fn -> Compose.update_service(%{}, "cloudflared") end)

    # Let the pull complete and the slow `up` begin, then sever the caller the
    # way a cloudflared recreate severs the LiveView's websocket.
    assert_receive {:pull, "cloudflared"}, 1_000
    Process.exit(caller, :kill)

    # The detached, supervised task must still finish recreating the service.
    assert_receive {:up, "cloudflared"}, 2_000
  end
end
