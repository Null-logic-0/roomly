defmodule RoomlyWeb.RoomLive.Show do
  use RoomlyWeb, :live_view

  alias Roomly.Rooms
  alias RoomlyWeb.Presence

  import RoomlyWeb.Room.AppHeader
  import RoomlyWeb.Room.AppFooter

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
    <Layouts.flash_group flash={@flash} />

    <div class="bg-gray-900 w-full h-screen flex flex-col overflow-hidden">
      <.app_header room={@room} seconds={@elapsed_seconds} />

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
                  <.icon name="hero-speaker-x-mark" class="size-3 text-white" />
                </span>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </main>

      <.app_footer
        message_form={@message_form}
        room={@room}
        messages={@streams.messages}
        messages_count={@messages_count}
        presences={@presences}
      />
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
    users = [
      %{id: "me", name: "You", color: "#1a73e8", muted: false},
      %{id: "u1", name: "Alex", color: "#34a853", muted: false}
      # %{id: "u2", name: "Sam", color: "#fbbc04", muted: true},
      # %{id: "u3", name: "Jordan", color: "#ea4335", muted: false},
      # %{id: "u4", name: "Jordan", color: "#ea4335", muted: false},
      # %{id: "u5", name: "Jordan", color: "#ea4335", muted: false},
      # %{id: "u6", name: "Jordan", color: "#ea4335", muted: false},
      # %{id: "u7", name: "Jordan", color: "#ea4335", muted: false}
    ]

    current_scope = socket.assigns.current_scope

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Roomly.PubSub, topic(slug))
      :timer.send_interval(1000, self(), :tick)

      {:ok, _} =
        Presence.track(self(), topic(slug), current_scope.user.id, %{
          username: current_scope.user.username,
          profile_image: current_scope.user.profile_image
        })
    end

    presences =
      if connected?(socket) do
        Presence.list(topic(slug))
      else
        %{}
      end

    messages = Rooms.list_messages(slug)

    case Rooms.get_room_by_slug!(slug) do
      nil ->
        {:ok, redirect(socket, to: "/")}

      room ->
        socket =
          socket
          |> assign(:room, room)
          |> assign(:page_title, "#{room.slug}")
          |> assign(:users, users)
          |> assign(:message_form, to_form(%{}))
          |> stream(:messages, messages)
          |> assign(:messages_count, length(messages))
          |> assign(:speaking_id, nil)
          |> assign(:presences, presence_map(presences))
          |> assign(:joined_at, System.monotonic_time(:second))
          |> assign(:elapsed_seconds, 0)

        {:ok, socket}
    end
  end

  defp topic(slug), do: "participants:#{slug}"

  def handle_event("send_message", %{"body" => body}, socket) do
    slug = socket.assigns.room.slug
    scope = socket.assigns.current_scope

    send_message =
      Rooms.create_message(scope, slug, %{context: body})

    case send_message do
      {:ok, _message} ->
        {:noreply, push_event(socket, "clear_input", %{})}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("send_message_keydown", %{"key" => "Enter", "value" => body}, socket) do
    handle_event("send_message", %{"body" => body}, socket)
  end

  def handle_event("send_message_keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_info({:new_message, message}, socket) do
    socket =
      socket
      |> stream_insert(:messages, message)
      |> update(:messages_count, &(&1 + 1))

    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    elapsed = System.monotonic_time(:second) - socket.assigns.joined_at
    {:noreply, assign(socket, :elapsed_seconds, elapsed)}
  end

  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    socket =
      socket
      |> remove_presences(diff.leaves)
      |> add_presences(diff.joins)

    {:noreply, socket}
  end

  defp remove_presences(socket, leaves) do
    current_user_id = to_string(socket.assigns.current_scope.user.id)

    leaving_users =
      leaves
      |> Enum.reject(fn {user_id, _} -> user_id == current_user_id end)

    user_ids = Enum.map(leaving_users, fn {user_id, _} -> user_id end)

    flash_message =
      leaving_users
      |> Enum.map(fn {_, info} ->
        metas = info[:metas] || info["metas"] || []

        case metas do
          [meta | _] -> meta[:username] || meta["username"]
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> case do
        [] -> nil
        [name] -> "#{name} left the room"
        [name1, name2] -> "#{name1} and #{name2} left the room"
        [name | _rest] -> "#{name} and others left the room"
      end

    presences = Map.drop(socket.assigns.presences, user_ids)
    socket = if flash_message, do: put_flash(socket, :info, flash_message), else: socket
    assign(socket, :presences, presences)
  end

  defp add_presences(socket, joins) do
    current_user_id = to_string(socket.assigns.current_scope.user.id)
    joining_users = Enum.reject(joins, fn {user_id, _} -> user_id == current_user_id end)

    flash_message =
      joining_users
      |> Enum.map(fn {_, info} ->
        metas = info[:metas] || info["metas"] || []

        case metas do
          [meta | _] -> meta[:username] || meta["username"]
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> case do
        [] -> nil
        [name] -> "#{name} joined the room"
        [name1, name2] -> "#{name1} and #{name2} joined the room"
        [name | _rest] -> "#{name} and others joined the room"
      end

    presences = Map.merge(socket.assigns.presences, presence_map_from_diff(joins))
    socket = if flash_message, do: put_flash(socket, :info, flash_message), else: socket
    assign(socket, :presences, presences)
  end

  defp presence_map(presences) do
    Enum.into(presences, %{}, fn {user_id, presence_map} ->
      metas = Map.get(presence_map, :metas) || Map.get(presence_map, "metas")
      [meta | _] = metas

      %{
        username: Map.get(meta, :username) || Map.get(meta, "username"),
        profile_image: Map.get(meta, :profile_image) || Map.get(meta, "profile_image")
      }
      |> then(&{user_id, &1})
    end)
  end

  defp presence_map_from_diff(presences) do
    Enum.into(presences, %{}, fn {user_id, info} ->
      metas = info[:metas] || info["metas"] || []

      case metas do
        [meta | _] ->
          {user_id,
           %{
             username: meta[:username] || meta["username"],
             profile_image: meta[:profile_image] || meta["profile_image"]
           }}

        _ ->
          {user_id, %{}}
      end
    end)
  end
end
