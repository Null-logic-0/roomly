defmodule RoomlyWeb.HomeLive do
  @moduledoc """
  Home page LiveView for Roomly.

  This is the entry point of the application where users can:
  - Create a new room
  - Navigate into an active video room
  """
  use RoomlyWeb, :live_view
  alias Roomly.Rooms
  import RoomlyWeb.HeroSection

  on_mount {RoomlyWeb.UserAuth, :mount_current_scope}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.hero_section current_scope={@current_scope} />
    </Layouts.app>
    """
  end

  @doc """
  Initializes the home page.

  Currently no state is required; relies on authenticated scope.
  """
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @doc """
  Creates a new room for the current user and redirects into it.
  """
  def handle_event("create_room", _, socket) do
    current_user = socket.assigns[:current_scope]

    {:ok, room} =
      Rooms.create_room(current_user)

    {:noreply, push_navigate(socket, to: "/room/#{room.slug}")}
  end
end
