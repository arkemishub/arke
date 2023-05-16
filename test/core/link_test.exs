defmodule Arke.Core.LinkTest do
  use Arke.RepoCase

  defp check_arke(_context) do
    ids = [:link_test, :test_arke_link_1, :test_unit_arke_1, :test_arke_link_1, :test_unit_arke_2]

    Enum.each(ids, fn id -> check_db(id) end)
  end

  describe "Link" do
    setup [:check_arke]

    test "create" do
      link_model = ArkeManager.get(:link, :arke_system)

      {:ok, link_unit} =
        QueryManager.create(:test_schema, link_model, %{
          id: "link_test",
          label: "testing",
          name: "testing"
        })

      arke_model = ArkeManager.get(:arke, :arke_system)

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_link_1",
        label: "Test Arke Link 1"
      })

      new_arke_model = ArkeManager.get(:test_arke_link_1, :test_schema)

      {:ok, unit_1} =
        QueryManager.create(:test_schema, new_arke_model, %{
          id: "test_unit_arke_1",
          label: "Test Unit 1"
        })

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_link_2",
        label: "Test Arke Link 2"
      })

      new_arke_model = ArkeManager.get(:test_arke_link_2, :test_schema)

      {:ok, unit_2} =
        QueryManager.create(:test_schema, new_arke_model, %{
          id: "test_unit_arke_2",
          label: "Test Unit 2"
        })

      arke_link_model = ArkeManager.get(:arke_link, :arke_system)

      {:ok, link_unit_db} =
        QueryManager.create(:test_schema, arke_link_model,
          parent_id: to_string(unit_1.id),
          child_id: to_string(unit_2.id),
          type: to_string(link_unit.id)
        )

      # FIXME: undefined table
      link =
        QueryManager.query(project: :test_schema, arke: :group)
        |> QueryManager.link(link_model, direction: :parent, type: to_string(link_unit.id))
        |> QueryManager.all()

      # Keep error until fixme is resolved
      assert 2 == 4
    end
  end
end
