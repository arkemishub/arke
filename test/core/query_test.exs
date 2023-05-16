defmodule Arke.Core.QueryTest do
  use Arke.RepoCase

  defp get_query(context), do: %{query: Query.new(nil, :test_schema)}

  describe "Query" do
    setup [:get_query]

    test "new" do
      query = Query.new(nil, :test_schema)
      assert query.arke == nil
      assert query.project == :test_schema
    end

    test "add_link_filter", %{query: query} = context do
      arke_model = ArkeManager.get(:arke, :arke_system)
      unit = Unit.load(arke_model, id: :unit_query_test, label: "Unit query test")
      link_filter = Query.add_link_filter(query, unit, 10, :child, "parameter")

      assert link_filter.link.depth == 10
      assert link_filter.link.unit.id == :unit_query_test
      assert link_filter.link.direction == :child
      assert link_filter.link.type == "parameter"
    end

    test "add_filter", %{query: query} = context do
      # Filter struct
      parameter = ParameterManager.get(:name, :arke_system)
      filter = Query.new_filter(parameter, :eq, "name", false)

      struct_filter = Query.add_filter(query, filter)

      assert is_list(struct_filter.filters) == true
      assert List.first(List.first(struct_filter.filters).base_filters).parameter.id == :name

      # add_filter/4 SHOULD BE SAME AS ABOVE

      base_filter = Query.new_base_filter(parameter, :contains, "test", false)

      filter = Query.add_filter(query, :or, false, [base_filter])

      assert is_list(struct_filter.filters) == true
      assert List.first(List.first(struct_filter.filters).base_filters).parameter.id == :name

      # add_filter/5 SHOULD BE SAME AS ABOVE

      filter = Query.add_filter(query, :min_length, :contains, "test", true)

      assert is_list(filter.filters) == true
      assert List.first(List.first(filter.filters).base_filters).parameter.id == :min_length
    end

    test "new_filter" do
      # new_filter/3
      filter = Query.new_filter(:or, true, Query.new_base_filter(:name, :contains, "test", false))
      assert filter.__struct__ == Arke.Core.Query.Filter
      assert filter.logic == :or
      assert List.first(filter.base_filters).parameter.id == :name

      # new_filter/4
      filter = Query.new_filter(:name, :gte, 12, false)
      assert filter.__struct__ == Arke.Core.Query.Filter
      assert filter.logic == :and
      assert List.first(filter.base_filters).operator == :gte
    end

    test "add_order", %{query: query} = context do
      # SHOULD WORK ALSO WITH ATOMS

      parameter = ParameterManager.get(:name, :arke_system)
      order = Query.add_order(query, parameter, :parent)

      assert List.first(order.orders).__struct__ == Arke.Core.Query.Order
      assert List.first(order.orders).direction == :parent
      assert List.first(order.orders).parameter.id == :name
    end

    test "set_offset", %{query: query} = context do
      # set_offset/2 when is_nil(nil)
      query_offset = Query.set_offset(query, nil)

      assert query_offset.offset == nil
      # set_offset/2 when is_binary(offset)
      query_offset = Query.set_offset(query, "5")

      assert query_offset.offset == 5

      # set_offset/2 when is_integer(offset)
      query_offset = Query.set_offset(query, 2)

      assert query_offset.offset == 2

      # set_offset/2 when offset is not valid
      query_offset = Query.set_offset(query, 2.5)

      assert query_offset == nil
      query_offset = Query.set_offset(query, :not_valid)

      assert query_offset == nil
    end

    test "set_limit", %{query: query} = context do
      # set_limit/2 when is_nil(nil)
      query_limit = Query.set_limit(query, nil)

      assert query_limit.limit == nil
      # set_limit/2 when is_binary(offset)
      query_limit = Query.set_limit(query, "5")

      assert query_limit.limit == 5

      # set_limit/2 when is_integer(offset)
      query_limit = Query.set_limit(query, 2)

      assert query_limit.limit == 2

      # set_limit/2 when offset is not valid
      query_limit = Query.set_limit(query, 2.5)

      assert query_limit == nil
      query_limit = Query.set_limit(query, :not_valid)

      assert query_limit == nil
    end
  end
end
