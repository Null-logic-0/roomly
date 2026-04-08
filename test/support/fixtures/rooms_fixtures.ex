defmodule Roomly.RoomsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Roomly.Rooms` context.
  """

  @doc """
  Generate a room.
  """
  def room_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        slug: "some slug"
      })

    {:ok, room} = Roomly.Rooms.create_room(scope, attrs)
    room
  end

  @doc """
  Generate a participant.
  """
  def participant_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        is_camera_on: true,
        is_muted: true
      })

    {:ok, participant} = Roomly.Rooms.create_participant(scope, attrs)
    participant
  end

  @doc """
  Generate a message.
  """
  def message_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        context: "some context"
      })

    {:ok, message} = Roomly.Rooms.create_message(scope, attrs)
    message
  end
end
