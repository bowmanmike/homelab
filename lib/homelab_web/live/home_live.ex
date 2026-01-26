defmodule HomelabWeb.HomeLive do
  use HomelabWeb, :live_view

  alias Homelab.{Docker, HostSignals}
  alias Homelab.Docker.Container

  @tick_interval :timer.seconds(1)

  def mount(_params, session, socket) do
    socket =
      assign_new(socket, :current_scope, fn -> session["current_scope"] end)

    socket =
      socket
      |> assign(:current_time, formatted_time())
      |> assign(:host_status, HostSignals.status())
      |> assign(:services_error, nil)
      |> assign(:services, [])

    case Docker.list_containers(all?: true) do
      {:ok, containers} ->
        {:ok,
         socket
         |> assign(:services, containers)
         |> schedule_tick()}

      {:error, reason} ->
        {:ok,
         socket
         |> assign(:services_error, docker_error_message(reason))
         |> schedule_tick()}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-col gap-6">
        <div class="rounded-3xl border border-base-300 bg-base-100 px-5 py-4 shadow-lg shadow-base-200/60 sm:px-6 sm:py-6">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            Signed in as
          </p>
          <p class="mt-2 text-2xl font-semibold text-base-content md:text-3xl">
            {@current_scope.user.email}
          </p>
        </div>

        <div class="grid gap-6 md:grid-cols-2">
          <div class="rounded-2xl border border-base-300 bg-base-100 px-5 py-4 sm:p-6">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              Current time (Eastern)
            </p>
            <p
              id="dashboard-clock"
              class="mt-2 font-mono text-2xl font-semibold tracking-tight sm:mt-3 md:text-4xl"
            >
              {@current_time}
            </p>
          </div>

          <div class="rounded-2xl border border-base-300 bg-base-100 px-5 py-4 sm:p-6">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60 flex items-center gap-4">
              Reboot status
              <span class={reboot_badge_classes(@host_status.reboot_required?)}>
                {reboot_badge_label(@host_status.reboot_required?)}
              </span>
            </p>
            <div class="mt-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-3">
              <p class="text-sm text-base-content sm:text-base">
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

      <div class="rounded-3xl border border-base-300 bg-base-100 px-5 py-5 shadow-xl shadow-base-200/60 sm:px-6 sm:py-6">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.3em] text-base-content/50">
              Docker services
            </p>
            <p class="mt-1 text-2xl font-semibold text-base-content">
              Runtime overview
            </p>
            <p class="mt-2 text-sm text-base-content/70">
              Every running container in the compose stack, refreshed on load.
            </p>
          </div>

          <div class="flex items-center gap-2">
            <%= if @services_error do %>
              <span class="inline-flex items-center gap-2 rounded-full bg-error/10 px-3 py-1 text-sm font-semibold text-error">
                <.icon name="hero-exclamation-triangle" class="size-4" />
                {@services_error}
              </span>
            <% else %>
              <span class="inline-flex items-center gap-2 rounded-full bg-success/10 px-3 py-1 text-sm font-semibold text-success">
                <.icon name="hero-check-circle" class="size-4" /> All systems reachable
              </span>
            <% end %>
          </div>
        </div>

        <div id="services-list" class="mt-6 grid gap-4">
          <%= if Enum.empty?(@services) do %>
            <div class="rounded-2xl border border-dashed border-base-300 bg-base-200/40 px-4 py-6 text-center text-sm text-base-content/70">
              No active containers detected.
            </div>
          <% end %>

          <div
            :for={container <- @services}
            id={"service-#{container.id}"}
            class="overflow-hidden rounded-2xl border border-base-300 bg-base-100 transition duration-200 ease-out hover:-translate-y-0.5 hover:border-primary/70 hover:shadow-lg hover:shadow-primary/10"
          >
            <.container_card container={container} />
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

  attr :container, Container, required: true

  defp container_card(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 p-5 sm:p-6">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            {@container.compose_project || "docker"}
            <%= if @container.compose_service do %>
              · {@container.compose_service}
            <% end %>
          </p>
          <p class="mt-2 text-xl font-semibold text-base-content">
            {container_label(@container)}
          </p>
          <p class="mt-1 text-sm text-base-content/70">
            {container_runtime(@container)}
          </p>
        </div>

        <span class={container_status_classes(@container.state)}>
          {String.upcase(@container.state || "unknown")}
        </span>
      </div>

      <dl class="grid gap-4 text-sm text-base-content/80">
        <div>
          <dt class="text-base-content/60">Image</dt>
          <dd class="mt-1 font-medium">{@container.image}</dd>
        </div>
        <div>
          <dt class="text-base-content/60">Status</dt>
          <dd class="mt-1 font-medium">{@container.status}</dd>
        </div>
      </dl>
    </div>
    """
  end

  defp container_label(%Container{name: name, compose_service: service, id: id}) do
    cond do
      is_binary(name) -> name
      is_binary(service) -> service
      true -> String.slice(id, 0, 12)
    end
  end

  defp container_runtime(%Container{created_at: nil}), do: "Started at unknown time"

  defp container_runtime(%Container{created_at: created_at}) do
    duration =
      DateTime.diff(DateTime.utc_now(), created_at, :second)
      |> humanize_seconds()

    "Up #{duration}"
  end

  defp container_status_classes("running") do
    "inline-flex items-center rounded-full bg-success/15 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-success"
  end

  defp container_status_classes("exited") do
    "inline-flex items-center rounded-full bg-error/10 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-error"
  end

  defp container_status_classes(_state) do
    "inline-flex items-center rounded-full bg-base-200 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-base-content/70"
  end

  defp humanize_seconds(seconds) when seconds < 60, do: "#{seconds}s"

  defp humanize_seconds(seconds) do
    minutes = div(seconds, 60)
    hours = div(minutes, 60)
    days = div(hours, 24)

    cond do
      days > 0 -> "#{days}d #{rem(hours, 24)}h"
      hours > 0 -> "#{hours}h #{rem(minutes, 60)}m"
      true -> "#{minutes}m"
    end
  end

  defp docker_error_message({:http_error, status, _body}), do: "Docker API error (#{status})"
  defp docker_error_message(%{} = error), do: inspect(error)
  defp docker_error_message(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp docker_error_message(reason), do: inspect(reason)
end
