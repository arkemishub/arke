defmodule Arke.Boundary.GroupManagerTest do
  use Arke.RepoCase, async: true

  alias Arke.LinkManager

  describe "GroupManager" do
    test "link arke to group" do
      # Create arke
      arke_model = ArkeManager.get(:arke, :arke_system)
      arke_data = [id: :test_arke_group, label: "Arke test"]
      arke_unit = Unit.load(arke_model, arke_data)
      ArkeManager.create(arke_unit, :arke_system)

      # Create group
      group_model = ArkeManager.get(:group, :arke_system)
      group_data = [id: "group_test", name: "group_test"]
      group_unit = Unit.load(group_model, group_data)
      GroupManager.create(group_unit, :arke_system)

      {:ok, link_unit} =
        LinkManager.add_node(
          :test_schema,
          group_unit,
          arke_unit,
          "group"
        )

      assert link_unit.data.type == "group"
      assert link_unit.data.parent_id == "group_test"
      assert link_unit.data.child_id == "test_arke_group"
    end

    test "get_groups_by_arke/1 (‰Arke.Core.Unit{})" do
      # Create arke
      arke_model = ArkeManager.get(:arke, :arke_system)
      arke_data = [id: :test_arke_group, label: "Arke test"]
      arke_unit = Unit.load(arke_model, arke_data)
      ArkeManager.create(arke_unit, :arke_system)

      # Create group
      group_model = ArkeManager.get(:group, :arke_system)
      group_data = [id: "group_test", name: "group_test"]
      group_unit = Unit.load(group_model, group_data)
      GroupManager.create(group_unit, :arke_system)

      LinkManager.add_node(:test_schema, group_unit, arke_unit, "group")

      arke_list = GroupManager.get_groups_by_arke(arke_unit)

      assert is_list(arke_list) == true
      assert List.first(arke_list).id == :group_test
    end

    test "get_groups_by_arke/2 (atoms)" do
      # Create arke
      arke_model = ArkeManager.get(:arke, :arke_system)
      arke_data = [id: :test_arke_group, label: "Arke test"]
      arke_unit = Unit.load(arke_model, arke_data)
      ArkeManager.create(arke_unit, :arke_system)

      # Create group
      group_model = ArkeManager.get(:group, :arke_system)
      group_data = [id: "group_test", name: "group_test"]
      group_unit = Unit.load(group_model, group_data)
      GroupManager.create(group_unit, :arke_system)

      LinkManager.add_node(:test_schema, group_unit, arke_unit, "group")

      arke_list = GroupManager.get_groups_by_arke(:test_arke_group, :test_schema)

      assert is_list(arke_list) == true
      assert length(List.first(arke_list)) > 0
      assert List.first(List.first(arke_list).data.arke_list).id == :test_arke_group
    end

    test "get_parameters/1 (‰Arke.Core.Unit{})" do
      # Create arke
      arke_model = ArkeManager.get(:arke, :arke_system)
      arke_data = [id: :test_arke_group, label: "Arke test"]
      arke_unit = Unit.load(arke_model, arke_data)
      ArkeManager.create(arke_unit, :arke_system)

      # Create group
      group_model = ArkeManager.get(:group, :arke_system)
      group_data = [id: "group_test", name: "group_test"]
      group_unit = Unit.load(group_model, group_data)
      GroupManager.create(group_unit, :arke_system)

      LinkManager.add_node(:test_schema, group_unit, arke_unit, "group")

      arke_list = GroupManager.get_parameters(group_unit)
      type_parameter = Enum.find(arke_list, fn el -> el.id == :type end)

      assert is_list(arke_list) == true
      assert type_parameter.arke_id == :string
      assert type_parameter.data.format == :attribute
    end

    test "get_parameters/1 (atoms)" do
      # Create arke
      arke_model = ArkeManager.get(:arke, :arke_system)
      arke_data = [id: :test_arke_group, label: "Arke test"]
      arke_unit = Unit.load(arke_model, arke_data)
      ArkeManager.create(arke_unit, :arke_system)

      # Create group
      group_model = ArkeManager.get(:group, :arke_system)
      group_data = [id: "group_test", name: "group_test"]
      group_unit = Unit.load(group_model, group_data)
      GroupManager.create(group_unit, :arke_system)

      LinkManager.add_node(:test_schema, group_unit, arke_unit, "group")

      arke_list = GroupManager.get_parameters(:group_test, :test_schema)
      type_parameter = Enum.find(arke_list, fn el -> el.id == :type end)

      assert is_list(arke_list) == true
      assert type_parameter.arke_id == :string
      assert type_parameter.data.format == :attribute
    end
  end
end
