defmodule RoomlyWeb.Room.AppHeader do
  use RoomlyWeb, :html

  @doc """
  Renders the header for a room session.

  Displays:
  - The room owner's name (uppercase) with "'S ROOM"
  - A live duration timer formatted as `HH:MM:SS`
  - A video indicator icon

  ## Assigns

    * `:room` - The room struct containing a nested `user` with `:username`
    * `:seconds` - Elapsed time in seconds (integer), displayed as formatted duration

  """
  attr :room, :map,
    required: true,
    doc: "Room struct with associated user (expects room.user.username)"

  attr :seconds, :integer, required: true, doc: "Elapsed time in seconds for the session"

  def app_header(assigns) do
    ~H"""
    <header class="flex justify-between items-center px-4 py-3 bg-gray-800 shrink-0">
      <h1 class="text-lg font-semibold text-white tracking-wide">
        {String.upcase(@room.user.username)}'S ROOM
      </h1>
      <div class="bg-indigo-500 px-3 py-1.5 text-white flex items-center gap-2 rounded-lg text-sm">
        <.icon name="hero-video-camera" class="size-4 text-red-400" />
        {format_duration(@seconds)}
      </div>
    </header>
    """
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = seconds |> rem(3600) |> div(60)
    secs = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B:~2..0B", [hours, minutes, secs]) |> IO.iodata_to_binary()
  end
end
