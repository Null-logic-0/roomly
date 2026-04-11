defmodule RoomlyWeb.RoomLive.UserBuilder do
  @moduledoc """
  Builds a normalized user list for the RoomLive UI.

  This module transforms:
  - current user
  - presence data
  - mute states

  into a unified list format used by the video grid and UI components.
  """

  @doc """
  Builds the list of users for rendering in the room.

  The result always includes:
  - the current user ("me") as the first element
  - all other connected users from presence data

  Each user is normalized into:
  `%{id, username, profile_image, muted}`
  """
  def build_users(my_id, current_user, presences, mute_states) do
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
end
