defmodule Arke.Boundary.ArkeTest do
  use Arke.RepoCase

  describe "ArkeManager" do
    test "get_all/0" do
      assert is_list(ArkeManager.get_all()) == true and ArkeManager.get_all() != []
    end

    test "get_all/1" do
      assert is_list(ArkeManager.get_all(:invalid_project)) == true and
               ArkeManager.get_all(:invalid_project) == []
    end

    test "get/2" do
      assert ArkeManager.get(:arke, :arke_system).id == :arke and
               ArkeManager.get(:arke, :arke_system).metadata.project == :arke_system
    end

    test "get/2 (error)" do
      {:error, msg} = ArkeManager.get(:not_valid, :arke_system)
      assert String.downcase(List.first(msg)[:message]) == "unit with id 'not_valid' not found"
    end

    test "create/1 " do
      data = [id: "arke_test", label: "Arke test"]
      arke = ArkeManager.get(:arke, :arke_system)
      unit = Unit.load(arke, data)
      {:ok, _pid} = ArkeManager.create(unit)

      assert %Arke.Core.Unit{} = ArkeManager.get(:arke_test, :arke_system)
    end

    test "create/2 " do
      data = [id: :arke_test_create, label: "Arke test"]
      arke = ArkeManager.get(:arke, :arke_system)
      unit = Unit.load(arke, data)
      {:ok, _pid} = ArkeManager.create(unit, :another_project)
      {:error, msg} = ArkeManager.get(:not_exist, :arke_system)

      assert %Arke.Core.Unit{} = ArkeManager.get(:arke_test_create, :another_project)

      assert String.downcase(List.first(msg)[:message]) ==
               "unit with id 'not_exist' not found"
    end

    test "get_parameters/0" do
      arke = ArkeManager.get(:arke, :arke_system)
      assert length(ArkeManager.get_parameters(arke)) > 0
    end

    test "get_parameter/3" do
      arke = ArkeManager.get(:arke, :arke_system)
      assert %Arke.Core.Unit{} = ArkeManager.get_parameter(arke, "label")
      assert %Arke.Core.Unit{} = ArkeManager.get_parameter(arke, :metadata)
      assert %Arke.Core.Unit{} = ArkeManager.get_parameter(:arke, :arke_system, :active)
      assert nil == ArkeManager.get_parameter(arke, :not_a_parameter)
    end
  end
end
