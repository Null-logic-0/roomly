defmodule RoomlyWeb.Room.Chat.Messages do
  use RoomlyWeb, :html

  @doc """
  Messages list
  """
  attr :messages, :any, required: true
  attr :messages_count, :integer, required: true

  def messages(assigns) do
    ~H"""
    <div class="flex flex-col" style="height: 240px;">
      <div
        id="chat-scroll"
        phx-hook="scroll_to_bottom"
        class="flex-1 overflow-y-auto p-2 space-y-1 min-h-0"
      >
        <div
          :if={@messages_count == 0}
          class="flex flex-col items-center justify-center h-full opacity-40 gap-2 py-8"
        >
          <.icon name="hero-chat-bubble-left-right" class="size-8" />
          <p class="text-sm">No messages yet. Say hello!</p>
        </div>

        <div id="chat-messages" phx-update="stream">
          <div
            :for={{dom_id, message} <- @messages}
            id={dom_id}
            class="chat chat-start"
          >
            <div class="chat-header flex gap-2 items-center">
              <span class="my-1 text-xs">{message.user.username}</span>
              <time class="text-xs opacity-50 ">
                {time_ago(message.inserted_at)}
              </time>
            </div>
            <div class="chat-bubble">{message.context}</div>
          </div>
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".scroll_to_bottom">
      export default {
        mounted(){ this.scrollToBottom() },
        updated(){ this.scrollToBottom() },
        scrollToBottom() {
          this.el.scrollTop = this.el.scrollHeight
        }
      }
    </script>
    """
  end

  defp time_ago(datetime) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), datetime)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hr ago"
      true -> "#{div(diff, 86400)} days ago"
    end
  end
end
