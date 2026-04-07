defmodule RoomlyWeb.HomeLive do
  use RoomlyWeb, :live_view

  on_mount {RoomlyWeb.UserAuth, :mount_current_scope}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}></Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
