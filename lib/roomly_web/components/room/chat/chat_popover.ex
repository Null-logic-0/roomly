defmodule RoomlyWeb.Room.Chat.ChatPopover do
  use RoomlyWeb, :html

  import RoomlyWeb.Room.Chat.ChatForm
  import RoomlyWeb.Room.Chat.Messages

  attr :messages, :any, required: true
  attr :messages_count, :integer, required: true
  attr :message_form, :any, required: true

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
        class="hidden absolute bottom-12 right-0 bg-base-100 rounded-box z-10 w-sm p-2 shadow-lg"
      >
        <.messages messages={@messages} messages_count={@messages_count} />
        <.chat_form form={@message_form} />
      </div>
    </div>
    """
  end
end
