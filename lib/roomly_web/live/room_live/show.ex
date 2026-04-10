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

      <main id="video-grid" style={grid_style(@tile_count)} class="flex-1 min-h-0 p-3">
        <div
          id="webrtc-hook"
          phx-hook="WebRTC"
          data-user-id={@my_id}
          phx-update="ignore"
          class="hidden"
        />

        <%= for {user, idx} <- Enum.with_index(@visible) do %>
          <%= if idx == 5 && @overflow > 0 do %>
            <div
              id="overflow-tile"
              class="rounded-xl bg-gray-700 flex flex-col items-center justify-center cursor-pointer hover:bg-gray-600 transition-colors"
            >
              <span class="text-3xl font-semibold text-white">+{@overflow}</span>
              <span class="text-xs text-gray-400 mt-1">more participants</span>
            </div>
          <% else %>
            <div
              id={"tile-#{user.id}"}
              phx-update="ignore"
              class="rounded-xl bg-gray-800 relative flex items-center justify-center overflow-hidden"
              data-speaking={to_string(user.id == @speaking_id)}
              data-my-tile={to_string(user.id == @my_id)}
              data-user-id={user.id}
            >
              <img
                id={"avatar-#{user.id}"}
                src={user.profile_image}
                alt={user.username}
                class="absolute w-14 h-14 rounded-full object-cover transition-opacity"
              />
              <%= if user.id == @my_id do %>
                <video
                  id="video-me"
                  autoplay
                  playsinline
                  muted
                  class="absolute inset-0 w-full h-full object-cover opacity-0"
                />
              <% else %>
                <div
                  id={"connecting-#{user.id}"}
                  class="absolute inset-0 flex flex-col items-center justify-center gap-2 z-20 rounded-xl bg-gray-900/70 transition-opacity duration-300"
                >
                  <div class="w-7 h-7 rounded-full border-2 border-white/10 border-t-indigo-400 animate-spin" />
                  <span class="text-xs text-white/60">Connecting...</span>
                </div>
                <video
                  id={"video-#{user.id}"}
                  autoplay
                  playsinline
                  muted
                  class="absolute inset-0 w-full h-full object-cover opacity-0"
                />
              <% end %>
              <span class="absolute bottom-2 left-2 text-xs text-white bg-black/50 px-2 py-0.5 rounded z-10">
                {user.username}
              </span>
              <%= if user.muted do %>
                <span
                  id={"mute-icon-#{user.id}"}
                  class="absolute bottom-2 right-2 bg-red-500 rounded-full w-5 h-5 flex items-center justify-center z-10"
                >
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
        muted={@muted}
        camera_off={@camera_off}
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

  def mount(%{"slug" => slug}, _session, socket) do
    current_scope = socket.assigns.current_scope
    my_id = to_string(current_scope.user.id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Roomly.PubSub, topic(slug))
      :timer.send_interval(1000, self(), :tick)

      Presence.track(self(), topic(slug), my_id, %{
        username: current_scope.user.username,
        profile_image: current_scope.user.profile_image
      })

      Roomly.RoomForwarder.ensure_started(slug)
    end

    presences =
      if connected?(socket) do
        Presence.list(topic(slug))
      else
        %{}
      end

    presence_data = presence_map(presences)

    mute_states = %{}
    users = build_users(my_id, current_scope.user, presence_data, mute_states)
    messages = Rooms.list_messages(slug)

    case Rooms.get_room_by_slug!(slug) do
      nil ->
        {:ok, redirect(socket, to: "/")}

      room ->
        socket =
          socket
          |> assign(:room, room)
          |> assign(:my_id, my_id)
          |> assign(:page_title, room.slug)
          |> assign(:users, users)
          |> assign(:mute_states, mute_states)
          |> assign(:message_form, to_form(%{}))
          |> stream(:messages, messages)
          |> assign(:messages_count, length(messages))
          |> assign(:speaking_id, nil)
          |> assign(:presences, presence_data)
          |> assign(:joined_at, System.monotonic_time(:second))
          |> assign(:elapsed_seconds, 0)
          |> assign(:muted, false)
          |> assign(:camera_off, false)

        {:ok, socket}
    end
  end

  defp topic(slug), do: "participants:#{slug}"

  #  WebRTC events

  def handle_event("webrtc_offer", %{"offer" => offer_json}, socket) do
    user_id = socket.assigns.my_id
    slug = socket.assigns.room.slug

    {:ok, answer_json} = Roomly.RoomForwarder.handle_offer(slug, user_id, offer_json)
    {:noreply, push_event(socket, "webrtc_answer", %{answer: answer_json})}
  end

  def handle_event("webrtc_renegotiate_answer", %{"answer" => answer_json}, socket) do
    Roomly.RoomForwarder.handle_answer(
      socket.assigns.room.slug,
      socket.assigns.my_id,
      answer_json
    )

    {:noreply, socket}
  end

  def handle_event("webrtc_ice", %{"candidate" => candidate_json}, socket) do
    Roomly.RoomForwarder.handle_ice_candidate(
      socket.assigns.room.slug,
      socket.assigns.my_id,
      candidate_json
    )

    {:noreply, socket}
  end

  def handle_event("toggle_mute", _params, socket) do
    muted = !socket.assigns.muted
    my_id = socket.assigns.my_id
    slug = socket.assigns.room.slug

    Phoenix.PubSub.broadcast(
      Roomly.PubSub,
      topic(slug),
      {:mute_state_change, my_id, muted}
    )

    {:noreply,
     socket
     |> assign(:muted, muted)
     |> push_event("set_mute", %{muted: muted})}
  end

  def handle_event("toggle_camera", _params, socket) do
    camera_off = !socket.assigns.camera_off

    {:noreply,
     socket
     |> assign(:camera_off, camera_off)
     |> push_event("set_camera", %{camera_off: camera_off})}
  end

  def handle_event("end_call", _params, socket) do
    slug = socket.assigns.room.slug
    my_id = socket.assigns.my_id

    Roomly.RoomForwarder.remove_peer(slug, my_id)

    {:noreply, socket |> push_event("end_call", %{}) |> redirect(to: ~p"/")}
  end

  # Chat events

  def handle_event("send_message", %{"body" => body}, socket) do
    case Rooms.create_message(socket.assigns.current_scope, socket.assigns.room.slug, %{
           context: body
         }) do
      {:ok, _message} -> {:noreply, push_event(socket, "clear_input", %{})}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("send_message_keydown", %{"key" => "Enter", "value" => body}, socket) do
    handle_event("send_message", %{"body" => body}, socket)
  end

  def handle_event("send_message_keydown", _params, socket) do
    {:noreply, socket}
  end

  # PubSub info handlers

  def handle_info({:peer_stream_id, sender_user_id, stream_id, target}, socket) do
    my_id = socket.assigns.my_id
    should_send = target == :all or target == my_id

    if should_send and sender_user_id != my_id do
      {:noreply,
       push_event(socket, "peer_stream_id", %{user_id: sender_user_id, stream_id: stream_id})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:webrtc_renegotiate, target_user_id, offer_json}, socket) do
    if target_user_id == socket.assigns.my_id do
      {:noreply, push_event(socket, "webrtc_renegotiate", %{offer: offer_json})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:webrtc_signal, target_user_id, signal}, socket) do
    if target_user_id == socket.assigns.my_id do
      {:noreply, push_event(socket, "webrtc_signal", signal)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:mute_state_change, user_id, muted}, socket) do
    mute_states = Map.put(socket.assigns.mute_states, user_id, muted)

    users =
      build_users(
        socket.assigns.my_id,
        socket.assigns.current_scope.user,
        socket.assigns.presences,
        mute_states
      )

    {:noreply,
     socket
     |> assign(:mute_states, mute_states)
     |> assign(:users, users)}
  end

  def handle_info({:toggle_mute, muted}, socket) do
    {:noreply, socket |> assign(:muted, muted) |> push_event("set_mute", %{muted: muted})}
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
    my_id = socket.assigns.my_id
    leaving_users = Enum.reject(leaves, fn {user_id, _} -> user_id == my_id end)

    Enum.each(leaving_users, fn {user_id, _} ->
      Roomly.RoomForwarder.remove_peer(socket.assigns.room.slug, user_id)
    end)

    leaving_ids = Enum.map(leaving_users, fn {user_id, _} -> user_id end)

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

    mute_states = Map.drop(socket.assigns.mute_states, leaving_ids)
    presences = Map.drop(socket.assigns.presences, leaving_ids)

    socket
    |> then(fn s -> if flash_message, do: put_flash(s, :info, flash_message), else: s end)
    |> assign(:presences, presences)
    |> assign(:mute_states, mute_states)
    |> assign(
      :users,
      build_users(my_id, socket.assigns.current_scope.user, presences, mute_states)
    )
  end

  defp add_presences(socket, joins) do
    my_id = socket.assigns.my_id
    joining_users = Enum.reject(joins, fn {user_id, _} -> user_id == my_id end)

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
    mute_states = socket.assigns.mute_states

    socket
    |> then(fn s -> if flash_message, do: put_flash(s, :info, flash_message), else: s end)
    |> assign(:presences, presences)
    |> assign(
      :users,
      build_users(my_id, socket.assigns.current_scope.user, presences, mute_states)
    )
  end

  defp build_users(my_id, current_user, presences, mute_states) do
    me = %{
      id: my_id,
      username: current_user.username,
      profile_image: current_user.profile_image,
      muted: Map.get(mute_states, my_id, false)
    }

    others =
      presences
      |> Enum.reject(fn {user_id, _} -> user_id == my_id end)
      |> Enum.map(fn {user_id, data} ->
        %{
          id: user_id,
          username: data.username,
          profile_image: data.profile_image,
          muted: Map.get(mute_states, user_id, false)
        }
      end)

    [me | others]
  end

  defp presence_map(presences) do
    Enum.into(presences, %{}, fn {user_id, presence_map} ->
      metas = Map.get(presence_map, :metas) || Map.get(presence_map, "metas")
      [meta | _] = metas

      {user_id,
       %{
         username: Map.get(meta, :username) || Map.get(meta, "username"),
         profile_image: Map.get(meta, :profile_image) || Map.get(meta, "profile_image")
       }}
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
