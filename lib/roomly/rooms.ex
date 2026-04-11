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

      iex> get_room_by_slug!("slug")
      %Room{}

      iex> get_room_by_slug!("invalid-slug")
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
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(scope, room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Scope{} = scope, %Room{} = room, attrs \\ %{}) do
    true = room.user_id == scope.user.id

    Room.changeset(room, attrs, scope)
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
  def subscribe_messages(slug) do
    Phoenix.PubSub.subscribe(Roomly.PubSub, "participants:#{slug}")
  end

  defp broadcast_message(slug, message) do
    Phoenix.PubSub.broadcast(Roomly.PubSub, "participants:#{slug}", {:new_message, message})
  end

  @doc """
  Returns the list of messages.

  ## Examples

      iex> list_messages(slug)
      [%Message{}, ...]

  """
  def list_messages(slug) do
    Message
    |> join(:inner, [m], r in Roomly.Rooms.Room, on: r.id == m.room_id)
    |> where([m, r], r.slug == ^slug)
    |> order_by([m], asc: m.inserted_at)
    |> preload(:user)
    |> Repo.all()
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
  def create_message(%Scope{} = scope, slug, attrs) do
    room = get_room_by_slug!(slug)

    with {:ok, message} <-
           %Message{}
           |> Message.changeset(Map.put(attrs, :room_id, room.id), scope)
           |> Repo.insert() do
      message = Repo.preload(message, :user)
      broadcast_message(slug, message)
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
