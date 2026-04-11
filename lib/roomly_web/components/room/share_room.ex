defmodule RoomlyWeb.Room.ShareRoom do
  use RoomlyWeb, :html

  @doc """
  Renders a share button with a dropdown containing the room URL.

  Features:
  - Displays a share icon button
  - Opens a dropdown with the full room URL
  - Allows users to copy the URL to clipboard
  - Provides visual feedback (icon change) after copying

  The component uses a colocated LiveView hook (`.copy_url`) to handle
  clipboard interaction on the client side.

  ## Assigns

    * `:room` - The room struct containing at least a `:slug` field

  """
  attr :room, :map,
    required: true,
    doc: "Room struct containing the slug used to build the share URL"

  def share_room(assigns) do
    ~H"""
    <div class="dropdown dropdown-top dropdown-end max-md:dropdown-center">
      <button tabindex="0" role="button" class="m-1 btn btn-ghost btn-square text-indigo-400">
        <.icon name="hero-share" class="size-5" />
      </button>
      <div
        tabindex="-1"
        class="dropdown-content menu bg-base-100 rounded-box z-1 p-2 shadow-sm"
      >
        <div class="flex items-center gap-2 bg-gray-700 rounded-lg px-3 py-2">
          <span class="text-sm text-gray-300 truncate flex-1 select-all">
            {RoomlyWeb.Endpoint.url() <> ~p"/room/#{@room.slug}"}
          </span>
          <button
            id="copy-url-btn"
            phx-hook=".copy_url"
            class="btn btn-ghost btn-square btn-sm text-indigo-400 shrink-0"
          >
            <.icon name="hero-clipboard" class="size-4" />
          </button>
        </div>
      </div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".copy_url">
      export default {
        mounted() {
          this.el.addEventListener("click", () => {
            const url = this.el.closest("div").querySelector("span").textContent.trim()
            navigator.clipboard.writeText(url).then(() => {
              this.el.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 18 4 13"/></svg>`
              setTimeout(() => {
                this.el.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>`
              }, 2000)
            })
          })
        }
      }
    </script>
    """
  end
end
