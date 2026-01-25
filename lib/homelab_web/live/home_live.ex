defmodule HomelabWeb.HomeLive do
  use HomelabWeb, :live_view

  alias Homelab.HostSignals

  @tick_interval :timer.seconds(1)

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_time, formatted_time())
     |> assign(:host_status, HostSignals.status())
     |> schedule_tick()}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-col gap-8">
        <div class="rounded-3xl border border-base-300 bg-base-100 p-6 shadow-lg shadow-base-200/60">
          <p class="text-sm uppercase tracking-wide text-base-content/60">Signed in as</p>
          <p class="mt-2 text-3xl font-semibold text-base-content">{@current_scope.user.email}</p>
          <p class="mt-1 text-sm text-base-content/70">
            Welcome back. Secure operations and telemetry will appear here soon.
          </p>
        </div>

        <div class="grid gap-6 md:grid-cols-2">
          <div class="rounded-2xl border border-base-300 bg-base-100 p-6">
            <p class="text-sm font-medium uppercase tracking-wide text-base-content/60">
              Current time (Eastern)
            </p>
            <p id="dashboard-clock" class="mt-3 font-mono text-4xl font-semibold tracking-tight">
              {@current_time}
            </p>
            <p class="mt-1 text-sm text-base-content/70">
              Synced to America/New_York for on-call coordination.
            </p>
          </div>

          <div class="rounded-2xl border border-base-300 bg-base-100 p-6">
            <p class="text-sm font-medium uppercase tracking-wide text-base-content/60">
              Reboot status
            </p>
            <div class="mt-3 flex items-center gap-3">
              <span class={reboot_badge_classes(@host_status.reboot_required?)}>
                {reboot_badge_label(@host_status.reboot_required?)}
              </span>
              <p class="text-base text-base-content">
                {reboot_description(@host_status.reboot_required?)}
              </p>
            </div>
            <p class="mt-4 text-sm text-base-content/70">
              Host uptime:
              <span class="font-semibold text-base-content">
                {uptime_text(@host_status.uptime)}
              </span>
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_info(:tick, socket) do
    {:noreply,
     socket
     |> assign(:current_time, formatted_time())
     |> assign(:host_status, HostSignals.status())
     |> schedule_tick()}
  end

  defp schedule_tick(socket) do
    if connected?(socket) do
      Process.send_after(self(), :tick, @tick_interval)
    end

    socket
  end

  defp formatted_time do
    DateTime.utc_now()
    |> DateTime.shift_zone!("America/New_York")
    |> Calendar.strftime("%B %d, %Y · %I:%M:%S %p %Z")
  end

  defp reboot_badge_classes({:ok, true}) do
    "inline-flex items-center rounded-full bg-warning/20 px-3 py-1 text-sm font-semibold text-warning"
  end

  defp reboot_badge_classes({:ok, false}) do
    "inline-flex items-center rounded-full bg-success/20 px-3 py-1 text-sm font-semibold text-success"
  end

  defp reboot_badge_classes({:error, _}) do
    "inline-flex items-center rounded-full bg-base-300 px-3 py-1 text-sm font-semibold text-base-content/60"
  end

  defp reboot_badge_label({:ok, true}), do: "Reboot required"
  defp reboot_badge_label({:ok, false}), do: "All clear"
  defp reboot_badge_label({:error, _}), do: "Unknown"

  defp reboot_description({:ok, true}) do
    "Apply updates and reboot the host when convenient."
  end

  defp reboot_description({:ok, false}) do
    "Kernel and packages are up-to-date."
  end

  defp reboot_description({:error, _}) do
    "Cannot read reboot signal from the host."
  end

  defp uptime_text({:ok, %{human: human}}), do: human
  defp uptime_text({:error, _}), do: "Unavailable"
end
