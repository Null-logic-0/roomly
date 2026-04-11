defmodule RoomlyWeb.RoomLive.PresenceHelpers do
  @moduledoc """
  Helper module for managing LiveView presence state and UI user reconciliation.

  Responsibilities:
  - Transforming Phoenix Presence data into UI-friendly user maps
  - Handling join/leave events and updating LiveView assigns
  - Coordinating mute state + presence consistency
  - Triggering RoomForwarder cleanup on user disconnect
  - Building flash messages for join/leave events

  This module acts as the bridge between:
  Phoenix Presence → LiveView assigns → UI rendering
  """

  alias RoomlyWeb.Presence
  alias Roomly.RoomForwarder
  alias RoomlyWeb.RoomLive.UserBuilder

  @doc """
  Handles users leaving the room.

  Responsibilities:
  - Removes peers from WebRTC forwarder
  - Cleans presence and mute state maps
  - Updates LiveView assigns
  - Generates user-friendly flash messages

  This is a full UI + session cleanup pipeline.
  """
  def remove_presences(socket, leaves) do
    my_id = socket.assigns.my_id
    leaving_users = Enum.reject(leaves, fn {user_id, _} -> user_id == my_id end)

    Enum.each(leaving_users, fn {user_id, _} ->
      RoomForwarder.remove_peer(socket.assigns.room.slug, user_id)
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
    |> then(fn s ->
      if flash_message, do: Phoenix.LiveView.put_flash(s, :info, flash_message), else: s
    end)
    |> Phoenix.Component.assign(:presences, presences)
    |> Phoenix.Component.assign(:mute_states, mute_states)
    |> Phoenix.Component.assign(
      :users,
      UserBuilder.build_users(my_id, socket.assigns.current_scope.user, presences, mute_states)
    )
  end

  @doc """
  Handles users joining the room.

  Responsibilities:
  - Merges new presence data into existing state
  - Updates user list for video grid
  - Generates join flash messages
  - Keeps current user stable in list ordering
  """
  def add_presences(socket, joins) do
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
    |> then(fn s ->
      if flash_message, do: Phoenix.LiveView.put_flash(s, :info, flash_message), else: s
    end)
    |> Phoenix.Component.assign(:presences, presences)
    |> Phoenix.Component.assign(
      :users,
      UserBuilder.build_users(my_id, socket.assigns.current_scope.user, presences, mute_states)
    )
  end

  def presence_map(presences) do
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

  @doc """
  Converts Presence diff format (joins/leaves) into normalized map structure.

  Used during incremental updates to LiveView assigns.
  """
  def presence_map_from_diff(presences) do
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

  @doc """
  Fetches current presence list for a given room slug.

  Wrapper around Phoenix Presence.
  """
  def list_for_socket(slug) do
    Presence.list("participants:#{slug}")
  end
end
