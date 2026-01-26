defmodule HomelabWeb.HomeLive do
  use HomelabWeb, :live_view

  alias HomelabWeb.DockerLive.Services
  alias HomelabWeb.HostLive.Signals

  def mount(_params, session, socket) do
    socket =
      assign_new(socket, :current_scope, fn -> session["current_scope"] end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-col gap-6">
        <%= live_render(@socket, Signals,
          id: "host-signals-panel",
          session: %{"current_scope" => @current_scope, "embedded?" => true}
        ) %>

        <%= live_render(@socket, Services,
          id: "docker-services-panel",
          session: %{"current_scope" => @current_scope, "embedded?" => true}
        ) %>
      </div>
    </Layouts.app>
    """
  end
end
