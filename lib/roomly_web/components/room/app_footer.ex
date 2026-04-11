defmodule RoomlyWeb.Room.AppFooter do
  use RoomlyWeb, :html
  import RoomlyWeb.Room.ParticipantsList
  import RoomlyWeb.Room.Chat.ChatPopover
  import RoomlyWeb.Room.ShareRoom

  @doc """
  Renders the footer controls for a room session.

  Features:
  - Displays the room slug
  - Media controls (mute/unmute, camera on/off, end call)
  - Chat popover with message count
  - Participants list dropdown
  - Share room dropdown

  ## Assigns

    * `:room` - Room struct containing at least a `:slug`
    * `:presences` - Presence map of active participants
    * `:messages` - List of chat messages
    * `:messages_count` - Total number of messages
    * `:message_form` - Phoenix form for sending messages
    * `:muted` - Boolean indicating if microphone is muted
    * `:camera_off` - Boolean indicating if camera is disabled

  ## Events

  - `"toggle_mute"` - Toggles microphone state
  - `"toggle_camera"` - Toggles camera state
  - `"end_call"` - Ends the current call/session

  """
  attr :room, :map, required: true, doc: "Room struct (expects :slug)"
  attr :presences, :map, required: true, doc: "Presence map of active participants"
  attr :messages, :list, required: true, doc: "List of chat messages"
  attr :messages_count, :integer, required: true, doc: "Total number of messages"
  attr :message_form, :any, required: true, doc: "Phoenix form for chat input"
  attr :muted, :boolean, required: true, doc: "Whether the microphone is muted"
  attr :camera_off, :boolean, required: true, doc: "Whether the camera is turned off"

  def app_footer(assigns) do
    ~H"""
    <footer class="shrink-0 bg-gray-800 px-4 py-3 flex flex-wrap items-center justify-between">
      <div class="text-indigo-400 text-sm bg-gray-700 px-3 py-1.5 rounded-lg">
        {@room.slug}
      </div>
      <div class="flex gap-3 items-center ">
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

      <div class="flex gap-2 items-center max-md:justify-center max-md:w-full">
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
