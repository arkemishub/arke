defmodule Arke.Core.GroupTest do
  use Arke.RepoCase, async: true

  alias Arke.LinkManager

  describe "Group CRUD" do
    test "create" do
      group_model = ArkeManager.get(:group, :arke_system)

      {:ok, unit} =
        QueryManager.create(:test_schema, group_model, %{id: "group_test", name: "group_test"})

      assert unit.id == :group_test
      assert unit.arke_id == :group

      # ADD unit to group
      arke_model = ArkeManager.get(:arke, :arke_system)

      {:ok, parent} =
        QueryManager.create(:test_schema, arke_model, %{id: "test_arke_group", label: "Test Arke"})

      LinkManager.add_node(:test_schema, "group_test", "test_arke_group", "group")
      group = GroupManager.get(:group_test, :test_schema)

      assert List.first(group.data.arke_list).id == :test_arke_group
    end

    test "read" do
      check_db(:group_test)
      group_model = ArkeManager.get(:group, :arke_system)
      QueryManager.create(:test_schema, group_model, %{id: "group_test", name: "group_test"})
      unit = QueryManager.get_by(id: :group_test, project: :test_schema)
      assert unit.id == :group_test
      assert unit.arke_id == :group
    end

    test "update" do
      check_db(:group_test)
      group_model = ArkeManager.get(:group, :arke_system)
      QueryManager.create(:test_schema, group_model, %{id: "group_test", name: "group_test"})
      old_group = QueryManager.get_by(id: :group_test, project: :test_schema)
      {:ok, edit_group} = QueryManager.update(old_group, %{name: "Group test edit"})

      assert old_group.id == edit_group.id and
               String.downcase(edit_group.data.name) == "group test edit"
    end

    test "delete" do
      check_db(:group_test)
      group_model = ArkeManager.get(:group, :arke_system)
      QueryManager.create(:test_schema, group_model, %{id: "group_test", name: "group_test"})

      assert QueryManager.delete(
               :test_schema,
               QueryManager.get_by(id: :group_test, project: :test_schema)
             ) == {:ok, nil}
    end
  end
end
