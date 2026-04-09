defmodule RoomlyWeb.Room.AppHeader do
  use RoomlyWeb, :html

  attr :room, :any, required: true
  attr :seconds, :any, required: true

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
