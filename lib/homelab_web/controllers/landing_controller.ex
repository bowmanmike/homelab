defmodule HomelabWeb.LandingController do
  use HomelabWeb, :controller

  alias Phoenix.LiveView.Controller, as: LiveController
  alias HomelabWeb.{HomeLive, UserLive}

  def home(%{assigns: %{current_scope: %{user: _user}}} = conn, _params) do
    LiveController.live_render(conn, HomeLive, session: session_payload(conn))
  end

  def home(conn, _params) do
    LiveController.live_render(conn, UserLive.Login, session: session_payload(conn))
  end

  defp session_payload(conn) do
    %{"current_scope" => conn.assigns[:current_scope]}
  end
end
