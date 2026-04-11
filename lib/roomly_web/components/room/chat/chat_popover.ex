defmodule RoomlyWeb.Room.Chat.ChatPopover do
  use RoomlyWeb, :html

  import RoomlyWeb.Room.Chat.ChatForm
  import RoomlyWeb.Room.Chat.Messages

  @doc """
  Renders a chat popover panel for a room.

  Features:
  - Toggle button to open/close the chat panel
  - Displays a list of messages
  - Includes a chat input form for sending new messages
  - Positioned as a floating popover above the footer

  The panel visibility is controlled via `JS.toggle/1`.

  ## Assigns

    * `:messages` - List of chat messages
    * `:messages_count` - Total number of messages
    * `:message_form` - Phoenix form for sending messages

  """
  attr :messages, :list, required: true, doc: "List of chat messages"
  attr :messages_count, :integer, required: true, doc: "Total number of messages"
  attr :message_form, :any, required: true, doc: "Phoenix form for chat input"

  def chat_popover(assigns) do
    ~H"""
    <div class="relative z-50">
      <button
        class="m-1 btn btn-ghost btn-square text-indigo-400"
        phx-click={JS.toggle(to: "#chat-panel")}
      >
        <.icon name="hero-chat-bubble-left" class="size-5" />
      </button>

      <div
        id="chat-panel"
        class="hidden absolute bottom-12 right-0 max-md:-left-20 bg-base-100 rounded-box z-10 w-sm max-md:w-xs p-2 shadow-lg"
      >
        <.messages messages={@messages} messages_count={@messages_count} />
        <.chat_form form={@message_form} />
      </div>
    </div>
    """
  end
end
