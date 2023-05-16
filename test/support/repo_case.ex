defmodule Arke.RepoCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias ArkePostgres.Repo
      alias Arke.Boundary.{ArkeManager, ParameterManager, GroupManager}
      alias Arke.QueryManager
      alias Arke.Core.Unit
      alias Arke.LinkManager
      alias Arke.Core.Query
      alias Arke.StructManager

      import Ecto
      import Ecto.Query
      import Arke.RepoCase

      # and any other stuff
    end
  end

  def check_db(id) do
    with nil <-
           Arke.QueryManager.get_by(id: id, project: :test_schema) do
      :ok
    else
      _ ->
        Arke.QueryManager.delete(
          :test_schema,
          Arke.QueryManager.get_by(id: id, project: :test_schema)
        )

        :ok
    end
  end

  defp check_project() do
    with nil <-
           Arke.QueryManager.get_by(
             id: "test_schema",
             arke_id: "arke_project",
             project: :arke_system
           ) do
      project = Arke.Boundary.ArkeManager.get(:arke_project, :arke_system)

      Arke.QueryManager.create(:arke_system, project, %{
        id: "test_schema",
        name: "test_schema",
        description: "test schema",
        type: "postgres_schema",
        label: "Test Project"
      })
    else
      _ -> nil
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ArkePostgres.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(ArkePostgres.Repo, {:shared, self()})
    end

    check_project()

    :ok
  end
end
