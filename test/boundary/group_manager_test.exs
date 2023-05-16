defmodule Arke.Boundary.GroupManagerTest do
  use Arke.RepoCase, async: true

  alias Arke.LinkManager

  defp check_group(_context) do
    with nil <- QueryManager.get_by(project: :test_schema, id: :group_test) do
      :ok
    else
      _ ->
        QueryManager.delete(
          :test_schema,
          QueryManager.get_by(id: :group_test, project: :test_schema)
        )

        QueryManager.delete(
          :test_schema,
          QueryManager.get_by(id: :test_arke_group, project: :test_schema)
        )

        :ok
    end
  end

  defp check_node(_context) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)

    query =
      Arke.QueryManager.query(project: :test_schema, arke: arke_link, type: :group)
      |> Arke.QueryManager.filter(:type, :eq, :group_test, false)

    case QueryManager.all(query) do
      [_unit] ->
        LinkManager.delete_node(:test_schema, :group_test, :test_arke_group, :group)
        :ok

      _ ->
        :ok
    end
  end

  describe "GroupManager" do
    setup [:check_node, :check_group]

    test "link arke to group" do
      arke_model = ArkeManager.get(:arke, :arke_system)

      {:ok, arke_unit} =
        QueryManager.create(:test_schema, arke_model, %{id: "test_arke_group", label: "Test Arke"})

      group_model = ArkeManager.get(:group, :arke_system)

      {:ok, group_unit} =
        QueryManager.create(:test_schema, group_model, %{id: "group_test", name: "group_test"})

      {:ok, link_unit} =
        LinkManager.add_node(
          :test_schema,
          to_string(group_unit.id),
          to_string(arke_unit.id),
          "group"
        )

      assert link_unit.data.type == "group"
      assert link_unit.data.parent_id == "group_test"
      assert link_unit.data.child_id == "test_arke_group"
    end

    test "get_groups_by_arke/1 (‰Arke.Core.Unit{})" do
      arke_model = ArkeManager.get(:arke, :arke_system)

      {:ok, arke_unit} =
        QueryManager.create(:test_schema, arke_model, %{id: "test_arke_group", label: "Test Arke"})

      group_model = ArkeManager.get(:group, :arke_system)
      QueryManager.create(:test_schema, group_model, %{id: "group_test", name: "group_test"})
      LinkManager.add_node(:test_schema, "group_test", "test_arke_group", "group")

      arke_list = GroupManager.get_groups_by_arke(arke_unit)

      assert is_list(arke_list) == true
      assert List.first(arke_list).id == :group_test
      assert List.first(List.first(arke_list).data.arke_list).id == :test_arke_group
    end

    test "get_groups_by_arke/2 (atoms)" do
      arke_model = ArkeManager.get(:arke, :arke_system)
      QueryManager.create(:test_schema, arke_model, %{id: "test_arke_group", label: "Test Arke"})

      group_model = ArkeManager.get(:group, :arke_system)

      {:ok, group_unit} =
        QueryManager.create(:test_schema, group_model, %{id: "group_test", name: "group_test"})

      LinkManager.add_node(:test_schema, "group_test", "test_arke_group", "group")

      arke_list = GroupManager.get_groups_by_arke(:test_arke_group, :test_schema)

      assert is_list(arke_list) == true
      assert List.first(arke_list).id == :group_test
      assert List.first(List.first(arke_list).data.arke_list).id == :test_arke_group
    end

    test "get_parameters/1 (‰Arke.Core.Unit{})" do
      arke_model = ArkeManager.get(:arke, :arke_system)
      QueryManager.create(:test_schema, arke_model, %{id: "test_arke_group", label: "Test Arke"})

      group_model = ArkeManager.get(:group, :arke_system)

      {:ok, group_unit} =
        QueryManager.create(:test_schema, group_model, %{id: "group_test", name: "group_test"})

      LinkManager.add_node(:test_schema, "group_test", "test_arke_group", "group")

      arke_list = GroupManager.get_parameters(group_unit)
      type_parameter = Enum.find(arke_list, fn el -> el.id == :type end)

      assert is_list(arke_list) == true
      assert type_parameter.arke_id == :string
      assert type_parameter.data.format == :attribute
    end

    test "get_parameters/1 (atoms)" do
      arke_model = ArkeManager.get(:arke, :arke_system)
      QueryManager.create(:test_schema, arke_model, %{id: "test_arke_group", label: "Test Arke"})

      group_model = ArkeManager.get(:group, :arke_system)
      QueryManager.create(:test_schema, group_model, %{id: "group_test", name: "group_test"})
      LinkManager.add_node(:test_schema, "group_test", "test_arke_group", "group")

      arke_list = GroupManager.get_parameters(:group_test, :test_schema)
      type_parameter = Enum.find(arke_list, fn el -> el.id == :type end)

      assert is_list(arke_list) == true
      assert type_parameter.arke_id == :string
      assert type_parameter.data.format == :attribute
    end
  end
end
