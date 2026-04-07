defmodule RoomlyWeb.PageController do
  use RoomlyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
