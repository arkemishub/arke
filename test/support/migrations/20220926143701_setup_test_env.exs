defmodule ArkePostgres.Repo.Migrations.SetupTestEnv do
  use Ecto.Migration

  def change do
    execute("create schema arke_system;")

    create table(:arke_unit, primary_key: false, prefix: "arke_system") do
      add(:id, :string, primary_key: true)
      add(:arke_id, :string, null: false)
      add(:data, :map, default: %{}, null: false)
      add(:configuration, :map, default: %{}, null: false)
      timestamps()
    end

    create table(:arke_link, primary_key: false, prefix: "arke_system") do
      add(:type, :string, default: "link", null: false)
      add(:parent_id, references(:arke_unit, column: :id, type: :string), primary_key: true)
      add(:child_id, references(:arke_unit, column: :id, type: :string), primary_key: true)
      add(:configuration, :map, default: %{}, primary_key: true)
    end

    create(index(:arke_link, :parent_id, prefix: "arke_system"))
    create(index(:arke_link, :child_id, prefix: "arke_system"))
    create(index(:arke_link, :configuration, prefix: "arke_system"))

    ## AUTH
    create table(:arke_auth, primary_key: false, prefix: "arke_system") do
      add(:type, :map, default: %{read: true, write: true, delete: false}, null: false)
      add(:parent_id, references(:arke_unit, column: :id, type: :string), primary_key: true)
      add(:child_id, references(:arke_unit, column: :id, type: :string), primary_key: true)
      add(:configuration, :map, default: %{})
    end

    create(index(:arke_auth, :parent_id, prefix: "arke_system"))
    create(index(:arke_auth, :child_id, prefix: "arke_system"))
    create(index(:arke_auth, :configuration, prefix: "arke_system"))
  end
end
