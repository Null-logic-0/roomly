defmodule RoomlyWeb.HomeLive do
  use RoomlyWeb, :live_view
  import RoomlyWeb.HeroSection
  alias Roomly.Rooms

  on_mount {RoomlyWeb.UserAuth, :mount_current_scope}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.hero_section current_scope={@current_scope} />
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("create_room", _, socket) do
    # your user scope
    current_user = socket.assigns[:current_scope]

    {:ok, room} =
      Rooms.create_room(current_user)

    {:noreply, push_navigate(socket, to: "/room/#{room.slug}")}
  end
end
