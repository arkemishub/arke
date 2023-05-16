defmodule Arke.Core.ArkeTest do
  use Arke.RepoCase

  describe "Arke CRUD" do
    test "create Arke" do
      check_db("test")
      arke_model = ArkeManager.get(:arke, :arke_system)

      {:ok, unit_created} =
        QueryManager.create(:test_schema, arke_model, %{id: "test", label: "Test Arke"})

      assert unit_created.id == :test
      assert ArkeManager.get(:test, :test_schema).id == :test
    end

    test "create Arke (error) " do
      arke_model = ArkeManager.get(:arke, :arke_system)
      {:error, msg} = QueryManager.create(:test_schema, arke_model, %{id: "test_error"})
      assert List.first(msg)[:context] == "parameter_validation"
    end

    test "read Arke" do
      check_db("test")
      arke_model = ArkeManager.get(:arke, :arke_system)
      QueryManager.create(:test_schema, arke_model, %{id: "test", label: "Test Arke"})

      arke = QueryManager.get_by(id: "test", project: :test_schema)
      assert arke.id == :test
    end

    test "read Arke (error)" do
      arke = QueryManager.get_by(id: "not_valid", project: :test_schema)
      assert arke == nil
    end

    test "edit Arke" do
      # Delete arke if present then create it
      check_db("test")
      arke_model = ArkeManager.get(:arke, :arke_system)
      QueryManager.create(:test_schema, arke_model, %{id: "test", label: "Test Arke"})

      old_arke = QueryManager.get_by(id: "test", project: :test_schema)
      {:ok, edit_arke} = QueryManager.update(old_arke, %{label: "Test Arke modificato"})

      assert old_arke.id == edit_arke.id and
               String.downcase(edit_arke.data.label) == "test arke modificato"
    end

    test "edit Arke (error)" do
      check_db("test")
      arke_model = ArkeManager.get(:arke, :arke_system)
      QueryManager.create(:test_schema, arke_model, %{id: "test", label: "Test Arke"})

      old_arke = QueryManager.get_by(id: "test", project: :test_schema)

      assert_raise FunctionClauseError, fn ->
        QueryManager.update(old_arke, %{label: :not_a_string})
      end
    end

    test "delete Arke" do
      check_db("test2")
      arke_model = ArkeManager.get(:arke, :arke_system)
      QueryManager.create(:test_schema, arke_model, %{id: "test2", label: "Test Arke"})
      assert ArkeManager.get(:test2, :test_schema).id == :test2

      assert QueryManager.delete(
               :test_schema,
               QueryManager.get_by(id: "test2", project: :test_schema)
             ) == {:ok, nil}

      {:error, msg} = ArkeManager.get(:test2, :test_schema)
      assert String.downcase(List.first(msg)[:message]) == "unit with id 'test2' not found"
    end

    test "delete Arke (error)" do
      assert_raise FunctionClauseError, fn ->
        QueryManager.delete(:test_schema, QueryManager.get_by(id: "test2", project: :test_schema))
      end
    end

    test "get_parameter" do
      arke_model = ArkeManager.get(:arke, :arke_system)

      parameter_label = Arke.Core.Arke.get_parameter(arke_model, :label)

      parameter_active = Arke.Core.Arke.get_parameter(arke_model, "active")

      parameter_not_associated = Arke.Core.Arke.get_parameter(arke_model, :max)

      parameter_from_manager = ParameterManager.get(:type, :arke_system)

      assert parameter_label.id == :label and parameter_label.data.persistence == "arke_parameter"

      assert parameter_active.id == :active and
               parameter_active.data.persistence == "arke_parameter"

      assert parameter_not_associated == nil

      assert Arke.Core.Arke.get_arke_parameter("ignored", parameter_from_manager) ==
               parameter_from_manager
    end
  end
end
