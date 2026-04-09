defmodule Roomly.Rooms do
  @moduledoc """
  The Rooms context.
  """

  import Ecto.Query, warn: false
  alias Roomly.Repo

  alias Roomly.Rooms.Room
  alias Roomly.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any room changes.

  The broadcasted messages match the pattern:

    * {:created, %Room{}}
    * {:updated, %Room{}}
    * {:deleted, %Room{}}

  """
  def subscribe_rooms(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Roomly.PubSub, "user:#{key}:rooms")
  end

  defp broadcast_room(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Roomly.PubSub, "user:#{key}:rooms", message)
  end

  @doc """
  Returns the list of rooms.

  ## Examples

      iex> list_rooms(scope)
      [%Room{}, ...]

  """
  def list_rooms(%Scope{} = scope) do
    Repo.all_by(Room, user_id: scope.user.id)
  end

  @doc """
  Gets a single room.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room!(scope, 123)
      %Room{}

      iex> get_room!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_room!(%Scope{} = scope, id) do
    Repo.get_by!(Room, id: id, user_id: scope.user.id)
  end

  @doc """
  Gets a single room by slug.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room_by_slug!(scope, "slug")
      %Room{}

      iex> get_room_by_slug!(scope, "invalid-slug")
      ** (Ecto.NoResultsError)

  """
  def get_room_by_slug!(slug) do
    Room
    |> where([r], r.slug == ^slug)
    |> preload(:user)
    |> Repo.one()
  end

  @doc """
  Creates a room.

  ## Examples

      iex> create_room(scope, %{field: value})
      {:ok, %Room{}}

      iex> create_room(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_room(%Scope{} = scope, attrs \\ %{}) do
    with {:ok, room = %Room{}} <-
           %Room{}
           |> Room.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_room(scope, {:created, room})
      {:ok, room}
    end
  end

  @doc """
  Updates a room.

  ## Examples

      iex> update_room(scope, room, %{field: new_value})
      {:ok, %Room{}}

      iex> update_room(scope, room, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_room(%Scope{} = scope, %Room{} = room, attrs) do
    true = room.user_id == scope.user.id

    with {:ok, room = %Room{}} <-
           room
           |> Room.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_room(scope, {:updated, room})
      {:ok, room}
    end
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(scope, room)
      {:ok, %Room{}}

      iex> delete_room(scope, room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%Scope{} = scope, %Room{} = room) do
    true = room.user_id == scope.user.id

    with {:ok, room = %Room{}} <-
           Repo.delete(room) do
      broadcast_room(scope, {:deleted, room})
      {:ok, room}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(scope, room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Scope{} = scope, %Room{} = room, attrs \\ %{}) do
    true = room.user_id == scope.user.id

    Room.changeset(room, attrs, scope)
  end

  alias Roomly.Rooms.Participant
  alias Roomly.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any participant changes.

  The broadcasted messages match the pattern:

    * {:created, %Participant{}}
    * {:updated, %Participant{}}
    * {:deleted, %Participant{}}

  """
  def subscribe_participants(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Roomly.PubSub, "user:#{key}:participants")
  end

  defp broadcast_participant(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Roomly.PubSub, "user:#{key}:participants", message)
  end

  @doc """
  Returns the list of participants.

  ## Examples

      iex> list_participants(scope)
      [%Participant{}, ...]

  """
  def list_participants(%Scope{} = scope) do
    Repo.all_by(Participant, user_id: scope.user.id)
  end

  @doc """
  Gets a single participant.

  Raises `Ecto.NoResultsError` if the Participant does not exist.

  ## Examples

      iex> get_participant!(scope, 123)
      %Participant{}

      iex> get_participant!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_participant!(%Scope{} = scope, id) do
    Repo.get_by!(Participant, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a participant.

  ## Examples

      iex> create_participant(scope, %{field: value})
      {:ok, %Participant{}}

      iex> create_participant(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_participant(%Scope{} = scope, attrs) do
    with {:ok, participant = %Participant{}} <-
           %Participant{}
           |> Participant.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_participant(scope, {:created, participant})
      {:ok, participant}
    end
  end

  @doc """
  Updates a participant.

  ## Examples

      iex> update_participant(scope, participant, %{field: new_value})
      {:ok, %Participant{}}

      iex> update_participant(scope, participant, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_participant(%Scope{} = scope, %Participant{} = participant, attrs) do
    true = participant.user_id == scope.user.id

    with {:ok, participant = %Participant{}} <-
           participant
           |> Participant.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_participant(scope, {:updated, participant})
      {:ok, participant}
    end
  end

  @doc """
  Deletes a participant.

  ## Examples

      iex> delete_participant(scope, participant)
      {:ok, %Participant{}}

      iex> delete_participant(scope, participant)
      {:error, %Ecto.Changeset{}}

  """
  def delete_participant(%Scope{} = scope, %Participant{} = participant) do
    true = participant.user_id == scope.user.id

    with {:ok, participant = %Participant{}} <-
           Repo.delete(participant) do
      broadcast_participant(scope, {:deleted, participant})
      {:ok, participant}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking participant changes.

  ## Examples

      iex> change_participant(scope, participant)
      %Ecto.Changeset{data: %Participant{}}

  """
  def change_participant(%Scope{} = scope, %Participant{} = participant, attrs \\ %{}) do
    true = participant.user_id == scope.user.id

    Participant.changeset(participant, attrs, scope)
  end

  alias Roomly.Rooms.Message
  alias Roomly.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any message changes.

  The broadcasted messages match the pattern:

    * {:created, %Message{}}
    * {:updated, %Message{}}
    * {:deleted, %Message{}}

  """
  def subscribe_messages(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Roomly.PubSub, "user:#{key}:messages")
  end

  defp broadcast_message(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Roomly.PubSub, "user:#{key}:messages", message)
  end

  @doc """
  Returns the list of messages.

  ## Examples

      iex> list_messages(scope)
      [%Message{}, ...]

  """
  def list_messages(%Scope{} = scope) do
    Repo.all_by(Message, user_id: scope.user.id)
  end

  @doc """
  Gets a single message.

  Raises `Ecto.NoResultsError` if the Message does not exist.

  ## Examples

      iex> get_message!(scope, 123)
      %Message{}

      iex> get_message!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(%Scope{} = scope, id) do
    Repo.get_by!(Message, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a message.

  ## Examples

      iex> create_message(scope, %{field: value})
      {:ok, %Message{}}

      iex> create_message(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(%Scope{} = scope, attrs) do
    with {:ok, message = %Message{}} <-
           %Message{}
           |> Message.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_message(scope, {:created, message})
      {:ok, message}
    end
  end

  @doc """
  Updates a message.

  ## Examples

      iex> update_message(scope, message, %{field: new_value})
      {:ok, %Message{}}

      iex> update_message(scope, message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_message(%Scope{} = scope, %Message{} = message, attrs) do
    true = message.user_id == scope.user.id

    with {:ok, message = %Message{}} <-
           message
           |> Message.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_message(scope, {:updated, message})
      {:ok, message}
    end
  end

  @doc """
  Deletes a message.

  ## Examples

      iex> delete_message(scope, message)
      {:ok, %Message{}}

      iex> delete_message(scope, message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_message(%Scope{} = scope, %Message{} = message) do
    true = message.user_id == scope.user.id

    with {:ok, message = %Message{}} <-
           Repo.delete(message) do
      broadcast_message(scope, {:deleted, message})
      {:ok, message}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(scope, message)
      %Ecto.Changeset{data: %Message{}}

  """
  def change_message(%Scope{} = scope, %Message{} = message, attrs \\ %{}) do
    true = message.user_id == scope.user.id

    Message.changeset(message, attrs, scope)
  end
end
