defmodule RoomlyWeb.Room.Video.VideoTile do
  use RoomlyWeb, :html

  attr :user, :map, required: true
  attr :my_id, :string, required: true
  attr :speaking_id, :string, default: nil

  def video_tile(assigns) do
    ~H"""
    <div
      id={"tile-#{@user.id}"}
      phx-update="ignore"
      class="rounded-xl bg-gray-800 relative flex items-center justify-center overflow-hidden"
      data-speaking={to_string(@user.id == @speaking_id)}
      data-my-tile={to_string(@user.id == @my_id)}
      data-user-id={@user.id}
    >
      <img
        id={"avatar-#{@user.id}"}
        src={@user.profile_image}
        alt={@user.username}
        class="absolute w-14 h-14 rounded-full object-cover transition-opacity"
      />
      <%= if @user.id == @my_id do %>
        <video
          id="video-me"
          autoplay
          playsinline
          muted
          class="absolute inset-0 w-full h-full object-cover opacity-0"
        />
      <% else %>
        <div
          id={"connecting-#{@user.id}"}
          class="absolute inset-0 flex flex-col items-center justify-center gap-2 z-20 rounded-xl bg-gray-900/70 transition-opacity duration-300"
        >
          <div class="w-7 h-7 rounded-full border-2 border-white/10 border-t-indigo-400 animate-spin" />
          <span class="text-xs text-white/60">Connecting...</span>
        </div>

        <video
          id={"video-#{@user.id}"}
          autoplay
          playsinline
          class="absolute inset-0 w-full h-full object-cover opacity-0"
        />
      <% end %>
      <span class="absolute bottom-2 left-2 text-xs text-white bg-black/50 px-2 py-0.5 rounded z-10">
        {@user.username}
      </span>
      <%= if @user.muted do %>
        <span
          id={"mute-icon-#{@user.id}"}
          class="absolute bottom-2 right-2 bg-red-500 rounded-full w-5 h-5 flex items-center justify-center z-10"
        >
          <.icon name="hero-speaker-x-mark" class="size-3 text-white" />
        </span>
      <% end %>
    </div>
    """
  end
end
