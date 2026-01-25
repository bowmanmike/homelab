defmodule HomelabWeb.PageController do
  use HomelabWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
