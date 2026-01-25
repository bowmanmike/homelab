defmodule HomelabWeb.HomeLive do
  use HomelabWeb, :live_view

  @tick_interval :timer.seconds(1)

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_time, formatted_time())
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
end
