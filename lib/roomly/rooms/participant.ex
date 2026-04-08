defmodule Roomly.Rooms.Participant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "participants" do
    field :is_muted, :boolean, default: false
    field :is_camera_on, :boolean, default: false
    belongs_to :room, Roomly.Rooms.Room
    belongs_to :user, Roomly.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(participant, attrs, user_scope) do
    participant
    |> cast(attrs, [:is_muted, :is_camera_on])
    |> validate_required([:is_muted, :is_camera_on])
    |> put_assoc(:user, user_scope.user)
  end
end
