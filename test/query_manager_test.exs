defmodule Arke.QueryManagerTest do
  use Arke.RepoCase

  test "CRUD functions" do
    arke_model = ArkeManager.get(:arke, :arke_system)

    # Create
    {:ok, unit} =
      QueryManager.create(:test_schema, arke_model, id: :query_create, label: "Query arke created")

    created_manager = ArkeManager.get(:query_create, :test_schema)

    assert unit.id == :query_create

    # Read
    unit_from_db = QueryManager.get_by(id: :query_create, project: :test_schema)

    assert unit_from_db.metadata.project == :test_schema

    # Update
    QueryManager.update(unit_from_db, label: "Query arke updated")
    updated_unit_from_db = QueryManager.get_by(id: :query_create, project: :test_schema)

    assert unit_from_db.id == updated_unit_from_db.id
    assert unit_from_db.data.label != updated_unit_from_db.data.label

    # Delete
    QueryManager.delete(:test_schema, unit_from_db)
    assert QueryManager.get_by(id: :query_create, project: :test_schema) == nil

    assert ArkeManager.get(:query_create, :test_schema) ==
             {:error,
              [
                %{
                  context: "Elixir.Arke.Boundary.ArkeManager",
                  message: "Unit with id 'query_create' not found"
                }
              ]}
  end

  defp load_unit(context) do
    arke_model = ArkeManager.get(:arke, :arke_system)
    %{unit: Unit.load(arke_model, id: :unit_query_test, label: "Unit query test")}
  end

  defp get_query(context) do
    %{query: QueryManager.query(project: :test_schema, arke: :string)}
  end

  describe "query" do
    setup [:load_unit, :get_query]

    test "new" do
      # when is nil (arke)
      query = QueryManager.query(project: :test_schema, arke: nil)
      assert query.arke == nil

      # when is binary (arke)
      query = QueryManager.query(project: :test_schema, arke: "string")
      assert query.arke.id == :string

      # when is atom (arke)
      query = QueryManager.query(project: :test_schema, arke: :string)
      assert query.arke.id == :string

      # when got from ArkeManager
      arke_model = ArkeManager.get(:string, :arke_system)
      query = QueryManager.query(project: :test_schema, arke: arke_model)
      assert query.arke.id == :string
    end

    test "link", %{unit: data} = context do
      query = QueryManager.query(project: :test_schema, arke: :string)

      # all atoms
      query_link = QueryManager.link(query, data, direction: :child, depth: 5, type: :parameter)

      assert query_link.link.unit.id == :unit_query_test
      assert query_link.link.depth == 5
      assert query_link.link.direction == :child
      assert query_link.link.type == :parameter

      # depth string
      query_link =
        QueryManager.link(query, data, direction: :child, depth: "10", type: :parameter)

      assert query_link.link.unit.id == :unit_query_test
      assert query_link.link.depth == 10
      assert query_link.link.direction == :child
      assert query_link.link.type == :parameter

      # depth invalid
      query_link = QueryManager.link(query, data, direction: :child, depth: nil, type: :parameter)

      assert query_link.link.unit.id == :unit_query_test
      assert query_link.link.depth == 500
      assert query_link.link.direction == :child
      assert query_link.link.type == :parameter

      # direction binary
      query_link =
        QueryManager.link(query, data, direction: "parent", depth: nil, type: :parameter)

      assert query_link.link.unit.id == :unit_query_test
      assert query_link.link.depth == 500
      assert query_link.link.direction == :parent
      assert query_link.link.type == :parameter
    end

    test "get_by" do
      unit_from_db = QueryManager.get_by(id: :test_schema, project: :arke_system)
      assert unit_from_db.id == :test_schema
    end

    test "get_by (not found)" do
      unit_from_db = QueryManager.get_by(id: :invalid_id, project: :arke_system)
      assert unit_from_db == nil
    end

    test "filter_by" do
      unit_from_db = QueryManager.filter_by(arke_id: :arke_project, project: :arke_system)
      assert is_list(unit_from_db) == true
      assert length(unit_from_db) > 0

      # when is map
      unit_from_db = QueryManager.filter_by(%{arke_id: :arke_project, project: :arke_system})
      assert List.first(unit_from_db).arke_id == :arke_project
      assert List.first(unit_from_db).metadata.project == :arke_system
    end

    test "filter_by (error)" do
      assert_raise FunctionClauseError, fn ->
        QueryManager.filter_by(invalid_column: :arke_project, project: :arke_system)
      end
    end

    test "and_", %{query: query} = context do
      assert_raise RuntimeError, "filters must be a list", fn ->
        QueryManager.and_(query, false, "invalid_filters") == "filters must be a list"
      end

      filter = QueryManager.conditions(arke_id__eq: "string")
      new_query = QueryManager.and_(query, false, filter)

      assert is_list(new_query.filters) == true
      assert List.first(new_query.filters).logic == :and
      assert List.first(List.first(new_query.filters).base_filters).operator == :eq
      assert List.first(List.first(new_query.filters).base_filters).negate == false
      assert List.first(List.first(new_query.filters).base_filters).value == "string"
    end

    test "or_", %{query: query} = context do
      assert_raise RuntimeError, "filters must be a list", fn ->
        QueryManager.or_(query, false, "invalid_filters") == "filters must be a list"
      end

      filter = QueryManager.conditions(arke_id__contains: "string")
      new_query = QueryManager.or_(query, true, filter)

      assert is_list(new_query.filters) == true
      assert List.first(new_query.filters).logic == :or
      assert List.first(List.first(new_query.filters).base_filters).operator == :contains
      assert List.first(List.first(new_query.filters).base_filters).negate == true
      assert List.first(List.first(new_query.filters).base_filters).value == "string"
    end

    test "condition" do
      ## TODO: fix new_base_filter and negate assignments
      cond = QueryManager.condition(:integer, :gte, 14, false)
      assert cond.parameter == :integer
      assert cond.operator == :gte
      assert cond.value == 14
      assert cond.negate == true
    end

    test "conditions" do
      ## TODO: fix new_base_filter

      cond = QueryManager.conditions(arke_id__contains: "string", age__gte: 12)
      cond0 = Enum.at(cond, 0)
      cond1 = Enum.at(cond, 1)

      assert length(cond) == 2

      assert cond0.parameter == "age"
      assert cond0.operator == :gte
      assert cond0.value == 13

      assert cond1.parameter == "arke_id"
      assert cond1.operator == :contains
      assert cond1.value == "string"
    end

    test "where", %{query: query} = context do
      where = QueryManager.where(query, arke_id__contains: "string")
      where_filter = List.first(List.first(where.filters).base_filters)

      assert where_filter.operator == :contains
      assert where_filter.value == "string"
    end

    test "filter", %{query: query} = context do
      parameter = ParameterManager.get(:id, :arke_system)
      filter = Arke.Core.Query.new_filter(parameter, :equal, "name", false)
      new_query = QueryManager.filter(query, filter)
      new_query_filters = List.first(List.first(new_query.filters).base_filters)

      assert new_query_filters.parameter.id == :id
      assert new_query_filters.operator == :equal
      assert new_query_filters.value == "name"

      new_query = QueryManager.filter(query, :min_length, :gte, 12, true)
      new_query_filters = List.first(List.first(new_query.filters).base_filters)

      assert new_query_filters.parameter.id == :min_length
      assert new_query_filters.operator == :gte
      assert new_query_filters.value == 12
      assert new_query_filters.negate == true

      # Group Filter

      # group as string
      new_query = QueryManager.filter(query, "group", :eq, "parameter", true)
      new_query_filters = List.first(List.first(new_query.filters).base_filters)

      assert new_query_filters.parameter.id == :arke_id
      assert new_query_filters.operator == :in
      assert is_list(new_query_filters.value) == true
      assert Enum.any?(new_query_filters.value, fn key -> "integer" end) == true
      assert new_query_filters.negate == true

      # group_id as string
      new_query = QueryManager.filter(query, "group_id", :eq, "parameter", true)
      new_query_filters = List.first(List.first(new_query.filters).base_filters)

      assert new_query_filters.parameter.id == :arke_id
      assert new_query_filters.operator == :in
      assert is_list(new_query_filters.value) == true
      assert Enum.any?(new_query_filters.value, fn key -> "integer" end) == true
      assert new_query_filters.negate == true

      # group as atom
      new_query = QueryManager.filter(query, :group, :eq, "parameter", true)
      new_query_filters = List.first(List.first(new_query.filters).base_filters)

      assert new_query_filters.parameter.id == :arke_id
      assert new_query_filters.operator == :in
      assert is_list(new_query_filters.value) == true
      assert Enum.any?(new_query_filters.value, fn key -> "integer" end) == true
      assert new_query_filters.negate == true

      # group_id as atom
      new_query = QueryManager.filter(query, :group_id, :eq, "parameter", true)
      new_query_filters = List.first(List.first(new_query.filters).base_filters)

      assert new_query_filters.parameter.id == :arke_id
      assert new_query_filters.operator == :in
      assert is_list(new_query_filters.value) == true
      assert Enum.any?(new_query_filters.value, fn key -> "integer" end) == true
      assert new_query_filters.negate == true
    end

    test "order", %{query: query} = context do
      # Arke in query nil
      new_query = QueryManager.query(project: :test_schema)
      add_order_query = QueryManager.order(new_query, :name, :asc)
      order = List.first(add_order_query.orders)

      assert order.parameter.id == :name
      assert order.direction == :asc

      parameter = ParameterManager.get(:id, :arke_system)

      add_order_query = QueryManager.order(new_query, parameter, :desc)
      order = List.first(add_order_query.orders)

      assert order.parameter.id == :id
      assert order.direction == :desc

      # Arke got from ArkeManager

      parameter = ParameterManager.get(:min_length, :arke_system)
      add_order_query = QueryManager.order(query, parameter, :asc)
      order = List.first(add_order_query.orders)

      assert order.parameter.id == :min_length
      assert order.direction == :asc

      add_order_query = QueryManager.order(query, "max_length", :desc)
      order = List.first(add_order_query.orders)

      assert order.parameter.id == :max_length
      assert order.direction == :desc

      add_order_query = QueryManager.order(query, :helper_text, :asc)
      order = List.first(add_order_query.orders)

      assert order.parameter.id == :helper_text
      assert order.direction == :asc

      add_order_query = QueryManager.order(query, :not_valid, :asc)
      order = List.first(add_order_query.orders)

      assert order.parameter == nil
      assert order.direction == :asc

      assert_raise ArgumentError, fn -> QueryManager.order(query, "not_existing_atom", :asc) end
    end

    test "offset", %{query: query} = context do
      query_offset = QueryManager.offset(query, 5)
      assert query_offset.offset == 5
    end

    test "limit", %{query: query} = context do
      query_limit = QueryManager.limit(query, 5)
      assert query_limit.limit == 5
    end

    test "pagination" do
      query =
        QueryManager.query(project: :arke_system)
        |> QueryManager.where(arke_id__contains: "project")

      {count, element} = QueryManager.pagination(query, 0, 10)
      assert count == 1
      assert List.first(element).arke_id == :arke_project
    end

    test "all" do
      query =
        QueryManager.query(project: :arke_system)
        |> QueryManager.where(arke_id__contains: "project")

      all = QueryManager.all(query)

      assert is_list(all) == true
      assert length(all) > 0
      assert List.first(all).arke_id == :arke_project
    end

    test "one" do
      query =
        QueryManager.query(project: :arke_system)
        |> QueryManager.where(arke_id__contains: "project")

      one = QueryManager.one(query)

      assert one.arke_id == :arke_project
      assert is_list(one) == false
    end

    test "raw" do
      query =
        QueryManager.query(project: :arke_system)
        |> QueryManager.where(arke_id__contains: "project")

      raw = QueryManager.raw(query)

      assert raw ==
               {"SELECT a0.\"id\", a0.\"arke_id\", a0.\"data\", a0.\"configuration\", a0.\"inserted_at\", a0.\"updated_at\" FROM \"arke_unit\" AS a0 WHERE (a0.\"arke_id\" LIKE $1)",
                ["%project%"]}
    end

    test "count" do
      query =
        QueryManager.query(project: :arke_system)
        |> QueryManager.where(arke_id__contains: "project")

      count = QueryManager.count(query)

      assert is_number(count) == true
      assert count > 0 == true
    end

    test "pseudo_query" do
      query =
        QueryManager.query(project: :arke_system)
        |> QueryManager.where(arke_id__contains: "project")

      pseudo = QueryManager.pseudo_query(query)

      assert pseudo.__struct__ == Ecto.Query
    end
  end
end
