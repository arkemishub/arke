defmodule Arke.Boundary.ArkeTest do
  use Arke.RepoCase

  def check_arke(id \\ "test") do
    with nil <- QueryManager.get_by(id: id, project: :test_schema) do
      :ok
    else
      _ -> QueryManager.delete(:test_schema, QueryManager.get_by(id: id, project: :test_schema))
    end
  end

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

    test "get/2 (error}" do
      {:error, msg} = ArkeManager.get(:not_valid, :arke_system)
      assert String.downcase(List.first(msg)[:message]) == "unit with id 'not_valid' not found"
    end
  end
end
