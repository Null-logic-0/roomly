defmodule RoomlyWeb.Room.Chat.ChatForm do
  use RoomlyWeb, :html

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
