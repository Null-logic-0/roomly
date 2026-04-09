defmodule Roomly.Rooms.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :slug, :string

    belongs_to :user, Roomly.Accounts.User
    has_many :participants, Roomly.Rooms.Participant
    has_many :messages, Roomly.Rooms.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs, user_scope) do
    room
    |> cast(attrs, [:context, :room_id])
    |> validate_required([:context, :room_id])
    |> put_change(:slug, generate_slug())
    |> put_assoc(:user, user_scope.user)
  end

  defp generate_slug() do
    parts =
      for _ <- 1..3 do
        :crypto.strong_rand_bytes(2)
        |> Base.url_encode64(padding: false)
        |> binary_part(0, 3)
      end

    Enum.join(parts, "-")
  end
end
