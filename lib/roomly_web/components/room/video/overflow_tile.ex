defmodule RoomlyWeb.Room.Video.OverflowTile do
  use RoomlyWeb, :html

  @doc """
  Renders a video grid overflow tile showing additional participants.

  This tile is displayed when there are more participants than visible
  video slots. It shows a `+N` indicator for hidden participants.

  ## Assigns

    * `:overflow` - Number of additional participants not shown in the grid

  """
  attr :overflow, :integer,
    default: 0,
    doc: "Number of hidden participants beyond visible video tiles"

  def overflow_tile(assigns) do
    ~H"""
    <div
      id="overflow-tile"
      class="rounded-xl bg-gray-700 flex flex-col items-center justify-center cursor-pointer hover:bg-gray-600 transition-colors"
    >
      <span class="text-3xl font-semibold text-white">+{@overflow}</span>
      <span class="text-xs text-gray-400 mt-1">more participants</span>
    </div>
    """
  end
end
