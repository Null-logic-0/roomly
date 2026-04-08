defmodule RoomlyWeb.RoomLive.Show do
  use RoomlyWeb, :live_view

  alias Roomly.Rooms
  alias Roomly.Accounts.Scope

  @max_visible 6

  def render(assigns) do
    assigns =
      assigns
      |> assign(:visible, Enum.take(assigns.users, @max_visible))
      |> then(fn a ->
        overflow = max(0, length(assigns.users) - @max_visible)
        tile_count = if overflow > 0, do: @max_visible, else: length(a.visible)
        assign(a, overflow: overflow, tile_count: tile_count)
      end)

    ~H"""
    <div class="bg-gray-900 w-full h-screen flex flex-col overflow-hidden">
      <header class="flex justify-between items-center px-4 py-3 bg-gray-800 shrink-0">
        <h1 class="text-lg font-semibold text-white tracking-wide">
          {String.upcase(@current_scope.user.username)}'S ROOM
        </h1>
        <div class="bg-indigo-500 px-3 py-1.5 text-white flex items-center gap-2 rounded-lg text-sm">
          <.icon name="hero-video-camera" class="size-4 text-red-400" /> 01:02:32
        </div>
      </header>

      <main style={grid_style(@tile_count)} class="flex-1 min-h-0 p-3">
        <%= for {user, idx} <- Enum.with_index(@visible) do %>
          <%= if idx == 5 && @overflow > 0 do %>
            <div class="rounded-xl bg-gray-700 flex flex-col items-center justify-center cursor-pointer hover:bg-gray-600 transition-colors">
              <span class="text-3xl font-semibold text-white">+{@overflow}</span>
              <span class="text-xs text-gray-400 mt-1">more participants</span>
            </div>
          <% else %>
            <div class={[
              "rounded-xl bg-gray-800 relative flex items-center justify-center overflow-hidden",
              user.id == "me" && "ring-2 ring-indigo-500",
              user.id == @speaking_id && "ring-2 ring-green-400"
            ]}>
              <div
                class="w-14 h-14 rounded-full flex items-center justify-center text-white font-semibold text-lg"
                style={"background-color: #{user.color}"}
              >
                {initials(user.name)}
              </div>
              <span class="absolute bottom-2 left-2 text-xs text-white bg-black/50 px-2 py-0.5 rounded">
                {user.name}
              </span>
              <%= if user.muted do %>
                <span class="absolute bottom-2 right-2 bg-red-500 rounded-full w-5 h-5 flex items-center justify-center">
                  <.icon name="hero-x-mark" class="size-3 text-white" />
                </span>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </main>

      <footer class="shrink-0 bg-gray-800 px-4 py-3 flex items-center justify-between">
        <div class="text-indigo-400 text-sm bg-gray-700 px-3 py-1.5 rounded-lg">
          {@current_scope.room.slug}
        </div>
        <div class="flex gap-3 items-center">
          <.button class="btn btn-square btn-ghost text-white">
            <.icon name="hero-speaker-wave" class="size-5" />
          </.button>
          <.button class="btn btn-square btn-ghost text-white">
            <.icon name="hero-video-camera" class="size-5" />
          </.button>
          <.button class="btn btn-error px-6">
            End Call
          </.button>
        </div>
        <div class="flex gap-2 items-center">
          <.button class="btn btn-ghost btn-square text-indigo-400">
            <.icon name="hero-chat-bubble-left" class="size-5" />
          </.button>
          <.button class="btn btn-ghost btn-square text-indigo-400">
            <.icon name="hero-users" class="size-5" />
          </.button>
        </div>
      </footer>
    </div>
    """
  end

  defp grid_style(n) do
    {cols, rows} =
      case n do
        1 -> {"1fr", "1fr"}
        2 -> {"1fr 1fr", "1fr"}
        3 -> {"1fr 1fr 1fr", "1fr"}
        4 -> {"1fr 1fr", "1fr 1fr"}
        5 -> {"repeat(3, 1fr)", "repeat(2, 1fr)"}
        _ -> {"repeat(3, 1fr)", "repeat(2, 1fr)"}
      end

    "display: grid; grid-template-columns: #{cols}; grid-template-rows: #{rows}; gap: 8px;"
  end

  defp initials(name), do: name |> String.slice(0, 2) |> String.upcase()

  def mount(%{"slug" => slug}, _session, socket) do
    current_scope = socket.assigns.current_scope

    users = [
      %{id: "me", name: "You", color: "#1a73e8", muted: false},
      %{id: "u1", name: "Alex", color: "#34a853", muted: false},
      %{id: "u2", name: "Sam", color: "#fbbc04", muted: true},
      %{id: "u3", name: "Jordan", color: "#ea4335", muted: false},
      %{id: "u4", name: "Jordan", color: "#ea4335", muted: false},
      %{id: "u5", name: "Jordan", color: "#ea4335", muted: false},
      %{id: "u6", name: "Jordan", color: "#ea4335", muted: false},
      %{id: "u7", name: "Jordan", color: "#ea4335", muted: false}
    ]

    case Rooms.get_room_by_slug!(current_scope, slug) do
      nil ->
        {:ok, redirect(socket, to: "/")}

      room ->
        {:ok,
         socket
         |> assign(:room, room)
         |> assign(:current_scope, %Scope{user: current_scope.user, room: room})
         |> assign(:users, users)
         |> assign(:speaking_id, nil)}
    end
  end
end
