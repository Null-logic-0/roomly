defmodule Roomly.Repo.Migrations.CreateParticipants do
  use Ecto.Migration

  def change do
    create table(:participants) do
      add :is_muted, :boolean, default: false, null: false
      add :is_camera_on, :boolean, default: true, null: false
      add :room_id, references(:rooms, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:participants, [:user_id])

    create index(:participants, [:room_id])
  end
end
