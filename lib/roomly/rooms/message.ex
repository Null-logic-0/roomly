defmodule Roomly.Rooms.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :context, :string
    belongs_to :room, Roomly.Rooms.Room
    belongs_to :user, Roomly.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs, user_scope) do
    message
    |> cast(attrs, [:context])
    |> validate_required([:context])
    |> put_assoc(:user, user_scope.user)
  end
end
