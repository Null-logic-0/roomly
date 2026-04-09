defmodule RoomlyWeb.Room.ParticipantsList do
  use RoomlyWeb, :html

  @doc """
   Participants presence list
  """
  attr :presences, :any, required: true

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
