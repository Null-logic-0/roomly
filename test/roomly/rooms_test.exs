defmodule Roomly.RoomsTest do
  use Roomly.DataCase

  alias Roomly.Rooms

  describe "rooms" do
    alias Roomly.Rooms.Room

    import Roomly.AccountsFixtures, only: [user_scope_fixture: 0]
    import Roomly.RoomsFixtures

    @invalid_attrs %{slug: nil}

    test "list_rooms/1 returns all scoped rooms" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room = room_fixture(scope)
      other_room = room_fixture(other_scope)
      assert Rooms.list_rooms(scope) == [room]
      assert Rooms.list_rooms(other_scope) == [other_room]
    end

    test "get_room!/2 returns the room with given id" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      other_scope = user_scope_fixture()
      assert Rooms.get_room!(scope, room.id) == room
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(other_scope, room.id) end
    end

    test "create_room/2 with valid data creates a room" do
      valid_attrs = %{slug: "some slug"}
      scope = user_scope_fixture()

      assert {:ok, %Room{} = room} = Rooms.create_room(scope, valid_attrs)
      assert room.slug == "some slug"
      assert room.user_id == scope.user.id
    end

    test "create_room/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Rooms.create_room(scope, @invalid_attrs)
    end

    test "update_room/3 with valid data updates the room" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      update_attrs = %{slug: "some updated slug"}

      assert {:ok, %Room{} = room} = Rooms.update_room(scope, room, update_attrs)
      assert room.slug == "some updated slug"
    end

    test "update_room/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room = room_fixture(scope)

      assert_raise MatchError, fn ->
        Rooms.update_room(other_scope, room, %{})
      end
    end

    test "update_room/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Rooms.update_room(scope, room, @invalid_attrs)
      assert room == Rooms.get_room!(scope, room.id)
    end

    test "delete_room/2 deletes the room" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      assert {:ok, %Room{}} = Rooms.delete_room(scope, room)
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(scope, room.id) end
    end

    test "delete_room/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room = room_fixture(scope)
      assert_raise MatchError, fn -> Rooms.delete_room(other_scope, room) end
    end

    test "change_room/2 returns a room changeset" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      assert %Ecto.Changeset{} = Rooms.change_room(scope, room)
    end
  end

  describe "participants" do
    alias Roomly.Rooms.Participant

    import Roomly.AccountsFixtures, only: [user_scope_fixture: 0]
    import Roomly.RoomsFixtures

    @invalid_attrs %{is_muted: nil, is_camera_on: nil}

    test "list_participants/1 returns all scoped participants" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      participant = participant_fixture(scope)
      other_participant = participant_fixture(other_scope)
      assert Rooms.list_participants(scope) == [participant]
      assert Rooms.list_participants(other_scope) == [other_participant]
    end

    test "get_participant!/2 returns the participant with given id" do
      scope = user_scope_fixture()
      participant = participant_fixture(scope)
      other_scope = user_scope_fixture()
      assert Rooms.get_participant!(scope, participant.id) == participant
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_participant!(other_scope, participant.id) end
    end

    test "create_participant/2 with valid data creates a participant" do
      valid_attrs = %{is_muted: true, is_camera_on: true}
      scope = user_scope_fixture()

      assert {:ok, %Participant{} = participant} = Rooms.create_participant(scope, valid_attrs)
      assert participant.is_muted == true
      assert participant.is_camera_on == true
      assert participant.user_id == scope.user.id
    end

    test "create_participant/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Rooms.create_participant(scope, @invalid_attrs)
    end

    test "update_participant/3 with valid data updates the participant" do
      scope = user_scope_fixture()
      participant = participant_fixture(scope)
      update_attrs = %{is_muted: false, is_camera_on: false}

      assert {:ok, %Participant{} = participant} = Rooms.update_participant(scope, participant, update_attrs)
      assert participant.is_muted == false
      assert participant.is_camera_on == false
    end

    test "update_participant/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      participant = participant_fixture(scope)

      assert_raise MatchError, fn ->
        Rooms.update_participant(other_scope, participant, %{})
      end
    end

    test "update_participant/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      participant = participant_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Rooms.update_participant(scope, participant, @invalid_attrs)
      assert participant == Rooms.get_participant!(scope, participant.id)
    end

    test "delete_participant/2 deletes the participant" do
      scope = user_scope_fixture()
      participant = participant_fixture(scope)
      assert {:ok, %Participant{}} = Rooms.delete_participant(scope, participant)
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_participant!(scope, participant.id) end
    end

    test "delete_participant/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      participant = participant_fixture(scope)
      assert_raise MatchError, fn -> Rooms.delete_participant(other_scope, participant) end
    end

    test "change_participant/2 returns a participant changeset" do
      scope = user_scope_fixture()
      participant = participant_fixture(scope)
      assert %Ecto.Changeset{} = Rooms.change_participant(scope, participant)
    end
  end

  describe "messages" do
    alias Roomly.Rooms.Message

    import Roomly.AccountsFixtures, only: [user_scope_fixture: 0]
    import Roomly.RoomsFixtures

    @invalid_attrs %{context: nil}

    test "list_messages/1 returns all scoped messages" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      message = message_fixture(scope)
      other_message = message_fixture(other_scope)
      assert Rooms.list_messages(scope) == [message]
      assert Rooms.list_messages(other_scope) == [other_message]
    end

    test "get_message!/2 returns the message with given id" do
      scope = user_scope_fixture()
      message = message_fixture(scope)
      other_scope = user_scope_fixture()
      assert Rooms.get_message!(scope, message.id) == message
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_message!(other_scope, message.id) end
    end

    test "create_message/2 with valid data creates a message" do
      valid_attrs = %{context: "some context"}
      scope = user_scope_fixture()

      assert {:ok, %Message{} = message} = Rooms.create_message(scope, valid_attrs)
      assert message.context == "some context"
      assert message.user_id == scope.user.id
    end

    test "create_message/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Rooms.create_message(scope, @invalid_attrs)
    end

    test "update_message/3 with valid data updates the message" do
      scope = user_scope_fixture()
      message = message_fixture(scope)
      update_attrs = %{context: "some updated context"}

      assert {:ok, %Message{} = message} = Rooms.update_message(scope, message, update_attrs)
      assert message.context == "some updated context"
    end

    test "update_message/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      message = message_fixture(scope)

      assert_raise MatchError, fn ->
        Rooms.update_message(other_scope, message, %{})
      end
    end

    test "update_message/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      message = message_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Rooms.update_message(scope, message, @invalid_attrs)
      assert message == Rooms.get_message!(scope, message.id)
    end

    test "delete_message/2 deletes the message" do
      scope = user_scope_fixture()
      message = message_fixture(scope)
      assert {:ok, %Message{}} = Rooms.delete_message(scope, message)
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_message!(scope, message.id) end
    end

    test "delete_message/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      message = message_fixture(scope)
      assert_raise MatchError, fn -> Rooms.delete_message(other_scope, message) end
    end

    test "change_message/2 returns a message changeset" do
      scope = user_scope_fixture()
      message = message_fixture(scope)
      assert %Ecto.Changeset{} = Rooms.change_message(scope, message)
    end
  end
end
