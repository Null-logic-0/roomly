defmodule RoomlyWeb.RoomLive.MountHelpers do
  @moduledoc """
  Helpers for initializing a RoomLive session.

  Responsible for:
  - Subscribing to PubSub topics
  - Tracking user presence
  - Starting WebRTC forwarder processes
  - Building the initial LiveView socket state
  - Hydrating users, messages, and presence data
  """
  alias RoomlyWeb.Presence
  alias RoomlyWeb.RoomLive.{PresenceHelpers, UserBuilder}
  alias Roomly.{Rooms, RoomForwarder}

  @topic_prefix "participants"

  @doc """
  Builds the PubSub topic for a given room slug.
  """
  def topic(slug), do: "#{@topic_prefix}:#{slug}"

  @doc """
  Initializes real-time room connection for a user.

  Responsibilities:
  - Subscribes to room PubSub topic
  - Starts heartbeat timer
  - Tracks user presence
  - Ensures WebRTC forwarder is running
  - Returns current presence list
  """
  def setup_connected(slug, my_id, user_meta, _socket) do
    Phoenix.PubSub.subscribe(Roomly.PubSub, topic(slug))
    :timer.send_interval(1000, self(), :tick)

    Presence.track(self(), topic(slug), my_id, user_meta)
    RoomForwarder.ensure_started(slug)

    Presence.list(topic(slug))
  end

  @doc """
  Builds the initial LiveView socket state for a room.

  This includes:
  - Room metadata
  - Current user identity
  - Presence data
  - Chat messages
  - Video/chat UI state (mute, camera, speaking)
  - User list construction
  """
  def build_initial_socket(socket, room, slug, my_id, current_user, connected?) do
    presences =
      if connected? do
        setup_connected(
          slug,
          my_id,
          %{
            username: current_user.username,
            profile_image: current_user.profile_image
          },
          socket
        )
      else
        %{}
      end

    presence_data = PresenceHelpers.presence_map(presences)
    mute_states = %{}
    users = UserBuilder.build_users(my_id, current_user, presence_data, mute_states)
    messages = Rooms.list_messages(slug)

    socket
    |> Phoenix.Component.assign(:room, room)
    |> Phoenix.Component.assign(:my_id, my_id)
    |> Phoenix.Component.assign(:page_title, room.slug)
    |> Phoenix.Component.assign(:users, users)
    |> Phoenix.Component.assign(:mute_states, mute_states)
    |> Phoenix.Component.assign(:message_form, Phoenix.Component.to_form(%{}))
    |> Phoenix.LiveView.stream(:messages, messages)
    |> Phoenix.Component.assign(:messages_count, length(messages))
    |> Phoenix.Component.assign(:speaking_id, nil)
    |> Phoenix.Component.assign(:presences, presence_data)
    |> Phoenix.Component.assign(:joined_at, System.monotonic_time(:second))
    |> Phoenix.Component.assign(:elapsed_seconds, 0)
    |> Phoenix.Component.assign(:muted, false)
    |> Phoenix.Component.assign(:camera_off, false)
  end
end
