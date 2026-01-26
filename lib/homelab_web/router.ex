defmodule HomelabWeb.Router do
  use HomelabWeb, :router

  import Phoenix.LiveDashboard.Router
  import HomelabWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HomelabWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HomelabWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", HomelabWeb do
  #   pipe_through :api
  # end

  # Enable dev-only dashboard + mailbox previews when requested
  if Application.compile_env(:homelab, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", HomelabWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{HomelabWeb.UserAuth, :require_authenticated}] do
      live "/docker", DockerLive.Services, :index
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    live_dashboard "/system/dashboard",
      metrics: HomelabWeb.Telemetry,
      ecto_repos: [Homelab.Repo]

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", HomelabWeb do
    pipe_through [:browser]

    get "/", LandingController, :home

    live_session :current_user,
      on_mount: [{HomelabWeb.UserAuth, :mount_current_scope}] do
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
