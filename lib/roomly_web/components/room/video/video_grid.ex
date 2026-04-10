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
    <main id="video-grid" style={grid_style(@tile_count)} class="flex-1 min-h-0 p-3">
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

  defp grid_style(n) do
    {cols, rows} =
      case n do
        1 -> {"1fr", "1fr"}
        2 -> {"1fr 1fr", "1fr"}
        3 -> {"1fr 1fr 1fr", "1fr"}
        4 -> {"1fr 1fr", "1fr 1fr"}
        5 -> {"repeat(3, 1fr)", "repeat(2, 1fr)"}
        _ -> {"repeat(3, 1fr)", "repeat(2, 1fr)"}
      end

    "display: grid; grid-template-columns: #{cols}; grid-template-rows: #{rows}; gap: 8px;"
  end
end
