defmodule RoomlyWeb.Room.ParticipantsList do
  use RoomlyWeb, :html

  @doc """
  Renders a dropdown list of active participants in a room.

  Displays:
  - A button with a user group icon
  - A dropdown containing the list of participants
  - Each participant’s profile image and username

  The component expects presence data (e.g. from `Phoenix.Presence`)
  where each entry contains user metadata.

  ## Assigns

    * `:presences` - A map of presence data in the format:
      `%{user_id => %{username: String.t(), profile_image: String.t()}}`

  """
  attr :presences, :map, required: true, doc: "Presence map keyed by user_id with user metadata"

  def participants_list(assigns) do
    ~H"""
    <div class="dropdown dropdown-top dropdown-end">
      <button tabindex="0" role="button" class="m-1 btn btn-ghost btn-square text-indigo-400">
        <.icon name="hero-user-group" class="size-5" />
      </button>
      <div
        tabindex="-1"
        class="dropdown-content bg-base-100 rounded-box z-1 w-40 p-2 shadow-sm"
      >
        <ul class="flex flex-col gap-4 overflow-y-scroll max-h-[300px]">
          <li :for={{_user_id, meta} <- @presences} class="flex gap-2 items-center">
            <img src={meta.profile_image} alt={meta.username} class="w-6 rounded-full" />
            <span class="">{meta.username}</span>
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
