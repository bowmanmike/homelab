defmodule HomelabWeb.DockerLive.Services do
  use HomelabWeb, :live_view

  alias Homelab.Docker
  alias Homelab.Docker.Container

  @refresh_interval :timer.seconds(5)

  def mount(_params, session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> session["current_scope"] end)
      |> assign(:embedded?, session["embedded?"] || false)
      |> assign(:services, [])
      |> assign(:services_error, nil)
      |> assign(:command_status, nil)

    {:ok, socket |> load_services() |> schedule_refresh()}
  end

  def render(%{embedded?: true} = assigns) do
    ~H"""
    <.docker_panel
      services={@services}
      services_error={@services_error}
      embedded?={true}
      command_status={@command_status}
    />
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.docker_panel
        services={@services}
        services_error={@services_error}
        embedded?={false}
        command_status={@command_status}
      />
    </Layouts.app>
    """
  end

  def handle_info(:refresh, socket) do
    {:noreply, socket |> load_services() |> schedule_refresh()}
  end

  def handle_event("start", %{"id" => container_id}, socket) do
    run_command(socket, container_id, fn scope ->
      Docker.start_container(scope, container_id)
    end, fn name -> "#{name} started." end)
  end

  def handle_event("stop", %{"id" => container_id}, socket) do
    run_command(socket, container_id, fn scope ->
      Docker.stop_container(scope, container_id)
    end, fn name -> "#{name} stopped." end)
  end

  def handle_event("restart", %{"id" => container_id}, socket) do
    run_command(socket, container_id, fn scope ->
      Docker.restart_container(scope, container_id)
    end, fn name -> "#{name} restarted." end)
  end

  def handle_event("pull", %{"id" => container_id, "image" => image}, socket) do
    run_command(socket, container_id, fn scope ->
      Docker.pull_image(scope, image)
    end, fn name -> "Requested image pull for #{name}." end)
  end

  defp run_command(socket, container_id, action_fun, success_message_fun) do
    container_name = container_name(socket.assigns.services, container_id)

    case action_fun.(socket.assigns.current_scope) do
      :ok ->
        {:noreply,
         socket
         |> assign(:command_status, {:ok, success_message_fun.(container_name)})
         |> load_services()}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:command_status, {:error, command_error(reason)})
         |> load_services()}
    end
  end

  defp container_name(containers, id) do
    case Enum.find(containers, &(&1.id == id)) do
      %Container{} = container -> container_label(container)
      _ -> id
    end
  end

  defp command_error({:http_error, status, _body}), do: "Docker API error (#{status})"
  defp command_error(%{} = error), do: inspect(error)
  defp command_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp command_error(reason), do: inspect(reason)

  defp load_services(socket) do
    case Docker.list_containers(all?: true) do
      {:ok, containers} ->
        socket
        |> assign(:services, containers)
        |> assign(:services_error, nil)

      {:error, reason} ->
        socket
        |> assign(:services_error, docker_error_message(reason))
        |> assign(:services, [])
    end
  end

  defp schedule_refresh(socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    socket
  end

  attr :services, :list, required: true
  attr :services_error, :string, default: nil
  attr :embedded?, :boolean, default: false
  attr :command_status, :any, default: nil

  defp docker_panel(assigns) do
    ~H"""
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
            {panel_description(@embedded?)}
          </p>
        </div>

        <div class="flex flex-col items-end gap-2 text-sm">
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
          <%= if @command_status do %>
            <span class={command_status_classes(@command_status)}>
              {command_status_label(@command_status)}
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
    """
  end

  defp panel_description(true), do: "Live snapshot from the host Docker engine."

  defp panel_description(false),
    do: "Every running container in the compose stack, refreshed continuously."

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

      <div class="mt-4 flex flex-wrap gap-3">
        <button
          :if={container_can_start?(@container)}
          id={"start-#{@container.id}"}
          phx-click="start"
          phx-value-id={@container.id}
          phx-disable-with="Starting…"
          class="btn btn-primary btn-sm"
        >
          <.icon name="hero-play" class="size-4" />
          <span class="ml-1">Start</span>
        </button>

        <button
          :if={container_can_stop?(@container)}
          id={"stop-#{@container.id}"}
          phx-click="stop"
          phx-value-id={@container.id}
          phx-disable-with="Stopping…"
          class="btn btn-outline btn-sm"
        >
          <.icon name="hero-pause" class="size-4" />
          <span class="ml-1">Stop</span>
        </button>

        <button
          id={"restart-#{@container.id}"}
          phx-click="restart"
          phx-value-id={@container.id}
          phx-disable-with="Restarting…"
          class="btn btn-ghost btn-sm"
          disabled={!container_can_restart?(@container)}
        >
          <.icon name="hero-arrow-path" class="size-4" />
          <span class="ml-1">Restart</span>
        </button>

        <button
          id={"pull-#{@container.id}"}
          phx-click="pull"
          phx-value-id={@container.id}
          phx-value-image={@container.image}
          phx-disable-with="Pulling…"
          class="btn btn-ghost btn-sm"
        >
          <.icon name="hero-arrow-down-tray" class="size-4" />
          <span class="ml-1">Pull latest</span>
        </button>
      </div>
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

  defp container_can_start?(%Container{state: state}) do
    state not in ["running", "restarting"]
  end

  defp container_can_stop?(%Container{state: state}) do
    state in ["running"]
  end

  defp container_can_restart?(%Container{state: state}) do
    state in ["running"]
  end

  defp command_status_classes({:ok, _}) do
    "inline-flex items-center gap-2 rounded-full bg-primary/10 px-3 py-1 text-sm font-semibold text-primary"
  end

  defp command_status_classes({:error, _}) do
    "inline-flex items-center gap-2 rounded-full bg-error/10 px-3 py-1 text-sm font-semibold text-error"
  end

  defp command_status_label({_, message}), do: message

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
