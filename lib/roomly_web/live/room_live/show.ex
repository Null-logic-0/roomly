defmodule RoomlyWeb.RoomLive.Show do
  @moduledoc """
  Main LiveView for the Room experience.

  This module orchestrates:
  - Video conferencing state (WebRTC via RoomForwarder)
  - Presence tracking (join/leave)
  - Chat system (messages + streaming)
  - UI state (mute, camera, speaking indicators)
  - PubSub event handling

  It acts as the central coordinator between:
  LiveView ↔ Presence ↔ WebRTC ↔ Chat system
  """
  use RoomlyWeb, :live_view

  alias Roomly.Rooms
  alias RoomlyWeb.RoomLive.{MountHelpers, PresenceHelpers, UserBuilder}

  import RoomlyWeb.Room.AppHeader
  import RoomlyWeb.Room.Video.VideoGrid
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

      <.video_grid
        my_id={@my_id}
        overflow={@overflow}
        speaking_id={@speaking_id}
        visible={@visible}
        tile_count={@tile_count}
      />

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

  @doc """
  Initializes the room session.

  Loads the room, builds initial socket state via MountHelpers,
  and connects user to PubSub + Presence if live.
  """
  def mount(%{"slug" => slug}, _session, socket) do
    current_scope = socket.assigns.current_scope
    my_id = to_string(current_scope.user.id)

    case Rooms.get_room_by_slug!(slug) do
      nil ->
        {:ok, redirect(socket, to: "/")}

      room ->
        {:ok,
         MountHelpers.build_initial_socket(
           socket,
           room,
           slug,
           my_id,
           current_scope.user,
           connected?(socket)
         )}
    end
  end

  # WebRTC events

  def handle_event("webrtc_offer", %{"offer" => offer_json}, socket) do
    {:ok, answer_json} =
      Roomly.RoomForwarder.handle_offer(
        socket.assigns.room.slug,
        socket.assigns.my_id,
        offer_json
      )

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
      MountHelpers.topic(slug),
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
           content: body
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
      UserBuilder.build_users(
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
    {:noreply,
     socket
     |> stream_insert(:messages, message)
     |> update(:messages_count, &(&1 + 1))}
  end

  def handle_info(:tick, socket) do
    elapsed = System.monotonic_time(:second) - socket.assigns.joined_at
    {:noreply, assign(socket, :elapsed_seconds, elapsed)}
  end

  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    socket =
      socket
      |> PresenceHelpers.remove_presences(diff.leaves)
      |> PresenceHelpers.add_presences(diff.joins)

    {:noreply, socket}
  end
end
