defmodule RoomlyWeb.Room.AppFooter do
  use RoomlyWeb, :html
  import RoomlyWeb.Room.ParticipantsList
  import RoomlyWeb.Room.Chat.ChatPopover
  import RoomlyWeb.Room.ShareRoom

  attr :presences, :any, required: true
  attr :messages, :any, required: true
  attr :messages_count, :integer, required: true
  attr :message_form, :any, required: true
  attr :room, :any, required: true
  attr :muted, :any, required: true
  attr :camera_off, :any, required: true

  def app_footer(assigns) do
    ~H"""
    <footer class="shrink-0 bg-gray-800 px-4 py-3 flex items-center justify-between">
      <div class="text-indigo-400 text-sm bg-gray-700 px-3 py-1.5 rounded-lg">
        {@room.slug}
      </div>
      <div class="flex gap-3 items-center">
        <.button
          phx-click="toggle_mute"
          class={["btn btn-square btn-ghost text-white", @muted && "bg-red-500/20 text-red-400"]}
        >
          <.icon
            name={if @muted, do: "hero-speaker-x-mark", else: "hero-speaker-wave"}
            class="size-5"
          />
        </.button>

        <.button
          phx-click="toggle_camera"
          class={["btn btn-square btn-ghost text-white", @camera_off && "bg-red-500/20 text-red-400"]}
        >
          <.icon
            name={if @camera_off, do: "hero-video-camera-slash", else: "hero-video-camera"}
            class="size-5"
          />
        </.button>

        <.button phx-click="end_call" class="btn btn-error px-6">
          End Call
        </.button>
      </div>

      <div class="flex gap-2 items-center">
        <.chat_popover
          message_form={@message_form}
          messages={@messages}
          messages_count={@messages_count}
        />
        <.participants_list presences={@presences} />
        <.share_room room={@room} />
      </div>
    </footer>
    """
  end
end
