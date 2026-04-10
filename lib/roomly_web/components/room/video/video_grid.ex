defmodule RoomlyWeb.Room.Video.VideoGrid do
  use RoomlyWeb, :html
  import RoomlyWeb.Room.Video.OverflowTile
  import RoomlyWeb.Room.Video.VideoTile

  attr :visible, :list, required: true
  attr :tile_count, :integer, required: true
  attr :overflow, :integer, default: 0
  attr :my_id, :string, required: true
  attr :speaking_id, :string, default: nil

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
