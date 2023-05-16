defmodule Arke.Boundary.ArkeTest do
  use ExUnit.Case
  alias Arke.QueryManager
  alias Arke.Boundary.ArkeManager

  def check_arke(id \\ "test")do
    with nil <- QueryManager.get_by(id: id, project: :test_schema) do
      :ok
    else _ -> QueryManager.delete(:test_schema,  QueryManager.get_by(id: id, project: :test_schema))
    end
  end

  defp check_project() do
    with nil <- QueryManager.get_by(id: "test_schema", project: :arke_system) do
      project = ArkeManager.get(:arke_project, :arke_system)
      QueryManager.create(:arke_system, project, %{id: "test_schema", name: "test_schema", description: "test schema", type: "postgres_schema"})
    else _ -> :ok
    end
  end

  setup do
    check_project()
    :ok
  end

  describe "ArkeManager" do

    test "get_all/0" do
      assert is_list(ArkeManager.get_all()) == true and ArkeManager.get_all() != []
    end
    test "get_all/1" do
      assert is_list(ArkeManager.get_all(:invalid_project)) == true and ArkeManager.get_all(:invalid_project) == []
    end

    test "get/2" do
      assert ArkeManager.get(:arke, :arke_system).id == :arke and ArkeManager.get(:arke, :arke_system).metadata.project == :arke_system
    end

    test "get/2 (error}" do
      {:error, msg} = ArkeManager.get(:not_valid, :arke_system)
      assert String.downcase(List.first(msg)[:message]) == "unit with id 'not_valid' not found"
    end

  end

  describe "Arke CRUD" do
    test "create Arke" do
      check_arke()
      arke_model = ArkeManager.get(:arke, :arke_system)
      {:ok, unit_created} = QueryManager.create(:test_schema, arke_model, %{id: "test", label: "Test Arke"})
      assert unit_created.id == :test
      assert ArkeManager.get(:test, :test_schema).id == :test
    end

    test "create Arke (error) " do
      arke_model = ArkeManager.get(:arke, :arke_system)
      {:error, msg} = QueryManager.create(:test_schema, arke_model, %{id: "test_error"})
      assert List.first(msg)[:context] == "parameter_validation"
    end
  end

  test "read Arke" do
    arke = QueryManager.get_by(id: "test", project: :test_schema)
    assert arke.id == :test
    end

  test "read Arke (error)" do
    arke = QueryManager.get_by(id: "not_valid", project: :test_schema)
      assert arke == nil
    end

  test "edit Arke" do
    old_arke = QueryManager.get_by(id: "test", project: :test_schema)
    {:ok, edit_arke} = QueryManager.update(old_arke, %{ label: "Test Arke modificato",})
    assert old_arke.id == edit_arke.id and String.downcase(edit_arke.data.label) == "test arke modificato"
  end

  test "edit Arke (error)" do
    old_arke = QueryManager.get_by(id: "test", project: :test_schema)
    assert_raise FunctionClauseError, fn -> QueryManager.update(old_arke, %{ label: :not_a_string,})  end
  end

  test "delete Arke" do
    check_arke("test2")
    arke_model = ArkeManager.get(:arke, :arke_system)
    QueryManager.create(:test_schema, arke_model, %{id: "test2", label: "Test Arke",})
    assert ArkeManager.get(:test2, :test_schema).id == :test2
    assert QueryManager.delete(:test_schema,  QueryManager.get_by(id: "test2", project: :test_schema)) ==  {:ok, nil}
    {:error, msg} = ArkeManager.get(:test2, :test_schema)
      assert String.downcase(List.first(msg)[:message]) == "unit with id 'test2' not found"
  end

  test "delete Arke (error)" do
    assert_raise FunctionClauseError, fn ->  QueryManager.delete(:test_schema, QueryManager.get_by(id: "test2", project: :test_schema)) end
  end


end
