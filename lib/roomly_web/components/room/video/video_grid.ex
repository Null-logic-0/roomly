defmodule RoomlyWeb.Room.Video.VideoGrid do
  use RoomlyWeb, :html
  import RoomlyWeb.Room.Video.OverflowTile
  import RoomlyWeb.Room.Video.VideoTile

  @doc """
  Renders the video grid layout for a room session.

  Features:
  - Dynamically adjusts grid layout based on participant count
  - Displays visible video tiles
  - Shows an overflow tile when participants exceed visible slots
  - Integrates WebRTC hook for real-time video streaming
  - Highlights the currently speaking user (if provided)

  ## Assigns

    * `:visible` - List of visible users to render in the grid
    * `:tile_count` - Number of tiles used to determine grid layout
    * `:overflow` - Number of hidden participants not shown in grid
    * `:my_id` - Current user ID (used by WebRTC hook)
    * `:speaking_id` - ID of user currently speaking (optional)

  """
  attr :visible, :list,
    required: true,
    doc: "List of visible users to render in the grid"

  attr :tile_count, :integer,
    required: true,
    doc: "Number of tiles used to determine grid layout"

  attr :overflow, :integer,
    default: 0,
    doc: "Number of participants not shown in the grid"

  attr :my_id, :string,
    required: true,
    doc: "Current user ID used by WebRTC hook"

  attr :speaking_id, :string,
    default: nil,
    doc: "ID of the user currently speaking"

  def video_grid(assigns) do
    ~H"""
    <main
      id="video-grid"
      class={["flex-1 min-h-0 p-2 sm:p-3 grid gap-2 sm:gap-3", grid_class(@tile_count)]}
    >
      <div
        id="webrtc-hook"
        phx-hook="WebRTC"
        data-user-id={@my_id}
        phx-update="ignore"
        class="hidden"
      />
      <%= for {user, idx} <- Enum.with_index(@visible) do %>
        <%= if idx == 5 && @overflow > 0 do %>
          <.overflow_tile overflow={@overflow} />
        <% else %>
          <.video_tile my_id={@my_id} speaking_id={@speaking_id} user={user} />
        <% end %>
      <% end %>
    </main>
    """
  end

  defp grid_class(n) do
    case n do
      1 -> "grid-cols-1 grid-rows-1"
      2 -> "grid-cols-1 grid-rows-2 sm:grid-cols-2 sm:grid-rows-1"
      3 -> "grid-cols-1 grid-rows-3 sm:grid-cols-3 sm:grid-rows-1"
      4 -> "grid-cols-2 grid-rows-2"
      5 -> "grid-cols-2 grid-rows-3 sm:grid-cols-3 sm:grid-rows-2"
      _ -> "grid-cols-2 grid-rows-3 sm:grid-cols-3 sm:grid-rows-2"
    end
  end
end
