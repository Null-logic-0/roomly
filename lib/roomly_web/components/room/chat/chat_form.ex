defmodule RoomlyWeb.Room.Chat.ChatForm do
  use RoomlyWeb, :html

  @doc """
  Renders a chat input form for sending messages in a room.

  Features:
  - Textarea input for composing messages
  - Submit button with send icon
  - Press **Enter** to send message
  - Use **Shift + Enter** for a new line
  - Automatically clears input after sending
  - Refocuses input on `"clear_input"` event

  Uses a colocated LiveView hook (`.message_input`) to handle:
  - Keyboard shortcuts (Enter to send)
  - Client-side input clearing and focus management

  ## Assigns

    * `:form` - Phoenix form struct used for message submission

  ## Events

  - `"send_message"` - Triggered on form submit or Enter key press
  - `"clear_input"` - Clears and refocuses the textarea (handled via JS hook)

  """
  attr :form, :any, required: true, doc: "Phoenix form struct for chat message input"

  def chat_form(assigns) do
    ~H"""
    <.form
      for={@form}
      phx-submit="send_message"
      class="flex gap-2 items-end relative"
    >
      <textarea
        name="body"
        class="textarea textarea-bordered w-full resize-none text-sm"
        rows="2"
        phx-hook=".message_input"
        id="message-input"
        placeholder="Type a message..."
      />
      <button
        type="submit"
        class="btn bg-indigo-500 btn-circle btn-sm absolute right-2 bottom-2"
      >
        <.icon name="hero-paper-airplane" class="size-4 text-white" />
      </button>
    </.form>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".message_input">
      export default {
        mounted() {
          this.el.addEventListener("keydown", (e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault()
              this.pushEvent("send_message", { body: this.el.value })
              this.el.value = ""
            }
          })
          this.handleEvent("clear_input", () => {
            this.el.value = ""
            this.el.focus()
          })
        }
      }
    </script>
    """
  end
end
