defmodule Arke.Core.ParameterTest do
  use Arke.RepoCase

  # make differents describe for each parameter type and for all of them make also some errors test
  defp get_query_node(child_id) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)

    Arke.QueryManager.query(project: :test_schema, arke: arke_link, type: :parameter)
    |> Arke.QueryManager.filter(:type, :eq, :parameter, false)
    |> Arke.QueryManager.filter(:child_id, :eq, child_id, false)
    |> Arke.QueryManager.filter(:parent_id, :eq, :test_arke_parameter, false)
  end

  defp check_arke(context) do
    with nil <- QueryManager.get_by(id: :test_arke_parameter, project: :test_schema) do
      arke_model = ArkeManager.get(:arke, :arke_system)
      arke_opts = [id: "test_arke_parameter", label: "test_arke_parameter", active: true]
      QueryManager.create(:test_schema, arke_model, arke_opts)
      :ok
    else
      _ ->
        ArkeManager.remove(:test_arke_parameter, :test_schema)
        check_arke(context)
    end
  end

  defp create_param(%{describe: type, opts: values} = context) do
    parameter_model = ArkeManager.get(String.to_atom(String.downcase(type)), :arke_system)
    QueryManager.create(:test_schema, parameter_model, values)
    :ok
  end

  defp create_param(id, values) do
    parameter_model = ArkeManager.get(id, :arke_system)
    QueryManager.create(:test_schema, parameter_model, values)
  end

  defp check_parameter_node(%{describe: type, opts: values} = context) do
    param_id = values[:id]
    arke = ArkeManager.get(:test_arke_parameter, :test_schema)
    query = get_query_node(param_id)

    with true <-
           length(Enum.filter(ArkeManager.get_parameters(arke), fn p -> p.id == param_id end)) > 0,
         length(QueryManager.all(query)) > 0 do
      %{link_status: "found"}
    else
      _ ->
        LinkManager.add_node(
          :test_schema,
          "test_arke_parameter",
          to_string(param_id),
          "parameter",
          %{}
        )

        %{link_status: "missing"}
    end
  end

  defp get_msg(id) do
    {:error,
     [
       %{
         context: "Elixir.Arke.Boundary.ParameterManager",
         message: "Unit with id '#{to_string(id)}' not found"
       }
     ]}
  end

  describe "String" do
    defp get_string_opts(context),
      do: %{opts: [id: :string_test, label: "Test String", min_length: 3, max_length: 5]}

    setup [:get_string_opts, :create_param, :check_arke, :check_parameter_node]

    test "create" do
      # Creation happens in the setup
      param = ParameterManager.get(:string_test, :test_schema)
      assert param.id == :string_test
    end

    test "associate" do
      parameter_model = ArkeManager.get(:string, :arke_system)

      QueryManager.create(:test_schema, parameter_model,
        id: :test_association_string,
        label: "Test Association String"
      )

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_string",
        "parameter",
        %{}
      )

      nodes = get_query_node(:test_association_string) |> QueryManager.all()
      unit = List.first(nodes)
      assert unit.data.parent_id == "test_arke_parameter"
      assert unit.data.child_id == "test_association_string"

      arke = ArkeManager.get(:test_arke_parameter, :test_schema)

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_string",
        "parameter",
        %{}
      )

      assert length(
               Enum.filter(ArkeManager.get_parameters(arke), fn p ->
                 p.id == :test_association_string
               end)
             ) > 0
    end

    test "create unit" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          string_test: "test",
          label: "First string unit"
        })

      assert unit.data.string_test == "test"
    end

    test "create unit (error)" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:error, msg} =
        QueryManager.create(:test_schema, arke_model, %{
          string_test: "test not valid",
          label: "First string unit"
        })

      assert msg == [%{context: "parameter_validation", message: "Test String: max length is 5"}]

      {:error, msg} =
        QueryManager.create(:test_schema, arke_model, %{
          string_test: "nv",
          label: "First string unit"
        })

      assert msg == [%{context: "parameter_validation", message: "Test String: min length is 3"}]
    end

    test "values" do
      opts = [id: :string_test_values, label: "Test String", values: ["first", "second"]]
      parameter_model = ArkeManager.get(:string, :arke_system)
      {:ok, parameter_unit} = QueryManager.create(:test_schema, parameter_model, opts)

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        to_string(parameter_unit.id),
        "parameter",
        %{}
      )

      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model,
          string_test_values: "first",
          label: "First string unit values"
        )

      {:error, msg} =
        QueryManager.create(:test_schema, arke_model,
          string_test_values: "not_valid",
          label: "First string unit values"
        )

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        to_string(:string_test_values),
        "parameter",
        %{}
      )

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert parameter_unit.data.values == [
               %{label: "First", value: "first"},
               %{label: "Second", value: "second"}
             ]

      assert unit.data.string_test_values == "first"

      assert msg == [
               %{
                 context: "parameter_validation",
                 message: "allowed values for string_test_values are: first, second"
               }
             ]
    end

    test "delete" do
      values = [
        id: :string_test_delete,
        label: "Test string delete",
        min_length: 3,
        max_length: 5
      ]

      {:ok, unit} = create_param(:string, values)

      param = ParameterManager.get(values[:id], :test_schema)
      assert param.id == values[:id]

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert ParameterManager.get(values[:id], :test_schema) == get_msg(values[:id])
    end
  end

  describe "Integer" do
    defp get_integer_opts(context),
      do: %{opts: [id: :integer_test, label: "Test Integer", min: 3, max: 5]}

    setup [:get_integer_opts, :create_param, :check_arke, :check_parameter_node]

    test "create" do
      # Creation happens in the setup
      param = ParameterManager.get(:integer_test, :test_schema)
      assert param.id == :integer_test
    end

    test "associate" do
      parameter_model = ArkeManager.get(:integer, :arke_system)

      QueryManager.create(:test_schema, parameter_model,
        id: :test_association_integer,
        label: "Test Association integer"
      )

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_integer",
        "parameter",
        %{}
      )

      nodes = get_query_node(:test_association_integer) |> QueryManager.all()
      unit = List.first(nodes)
      assert unit.data.parent_id == "test_arke_parameter"
      assert unit.data.child_id == "test_association_integer"

      arke = ArkeManager.get(:test_arke_parameter, :test_schema)

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_integer",
        "parameter",
        %{}
      )

      assert length(
               Enum.filter(ArkeManager.get_parameters(arke), fn p ->
                 p.id == :test_association_integer
               end)
             ) > 0
    end

    test "create unit" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          integer_test: 3,
          label: "First integer unit"
        })

      assert unit.data.integer_test == 3
    end

    test "create unit (error)" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          integer_test: 10,
          label: "First integer unit"
        })

      assert unit == [%{context: "parameter_validation", message: "Test Integer: max is 5"}]

      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          integer_test: 1,
          label: "First integer unit"
        })

      assert unit == [%{context: "parameter_validation", message: "Test Integer: min is 3"}]
    end

    test "values" do
      opts = [
        id: :integer_test_values,
        label: "Test integer",
        values: [1, 2, 3, 4],
        multiple: true
      ]

      parameter_model = ArkeManager.get(:integer, :arke_system)
      {:ok, parameter_unit} = QueryManager.create(:test_schema, parameter_model, opts)

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        to_string(parameter_unit.id),
        "parameter",
        %{}
      )

      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model,
          integer_test_values: [1, 2],
          label: "First integer unit values"
        )

      {:error, msg} =
        QueryManager.create(:test_schema, arke_model,
          integer_test_values: 9,
          label: "First integer unit values"
        )

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        to_string(:integer_test_values),
        "parameter",
        %{}
      )

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert parameter_unit.data.values == [
               %{label: "1", value: "1"},
               %{label: "2", value: "2"},
               %{label: "3", value: "3"},
               %{label: "4", value: "4"}
             ]

      # TODO: fix parsing if list of values is passed
      assert unit.data.integer_test_values == [1, 2]

      assert msg == [
               %{
                 context: "parameter_validation",
                 message: "allowed values for integer_test_values are: 1, 2, 3, 4"
               }
             ]
    end

    test "delete" do
      values = [id: :integer_test_delete, label: "Test integer delete"]
      {:ok, unit} = create_param(:integer, values)

      param = ParameterManager.get(values[:id], :test_schema)
      assert param.id == values[:id]

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert ParameterManager.get(values[:id], :test_schema) == get_msg(values[:id])
    end
  end

  describe "Float" do
    defp get_float_opts(context),
      do: %{opts: [id: :float_test, label: "Test float", min: 3, max: 5]}

    setup [:get_float_opts, :create_param, :check_arke, :check_parameter_node]

    test "create" do
      # Creation happens in the setup
      param = ParameterManager.get(:float_test, :test_schema)
      assert param.id == :float_test
    end

    test "associate" do
      parameter_model = ArkeManager.get(:float, :arke_system)

      QueryManager.create(:test_schema, parameter_model,
        id: :test_association_float,
        label: "Test Association float"
      )

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_float",
        "parameter",
        %{}
      )

      nodes = get_query_node(:test_association_float) |> QueryManager.all()
      unit = List.first(nodes)
      assert unit.data.parent_id == "test_arke_parameter"
      assert unit.data.child_id == "test_association_float"

      arke = ArkeManager.get(:test_arke_parameter, :test_schema)

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_float",
        "parameter",
        %{}
      )

      assert length(
               Enum.filter(ArkeManager.get_parameters(arke), fn p ->
                 p.id == :test_association_float
               end)
             ) > 0
    end

    test "create unit" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{float_test: 3, label: "First float unit"})

      assert unit.data.float_test == 3
    end

    test "create unit (error)" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{float_test: 10, label: "First float unit"})

      assert unit == [%{context: "parameter_validation", message: "Test float: max is 5"}]

      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{float_test: 1, label: "First float unit"})

      assert unit == [%{context: "parameter_validation", message: "Test float: min is 3"}]
    end

    test "values" do
      opts = [id: :float_test_values, label: "Test float", values: [1, 2, 3, 4], multiple: true]
      parameter_model = ArkeManager.get(:float, :arke_system)
      {:ok, parameter_unit} = QueryManager.create(:test_schema, parameter_model, opts)

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        to_string(parameter_unit.id),
        "parameter",
        %{}
      )

      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model,
          float_test_values: [1, 2],
          label: "First float unit values"
        )

      {:error, msg} =
        QueryManager.create(:test_schema, arke_model,
          float_test_values: 9,
          label: "First float unit values"
        )

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        to_string(:float_test_values),
        "parameter",
        %{}
      )

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      # TODO: fix parsing if list of values is passed
      assert parameter_unit.data.values == [
               %{label: "1", value: "1"},
               %{label: "2", value: "2"},
               %{label: "3", value: "3"},
               %{label: "4", value: "4"}
             ]

      assert unit.data.float_test_values == [1, 2]

      assert msg == [
               %{
                 context: "parameter_validation",
                 message: "allowed values for float_test_values are: 1, 2, 3, 4"
               }
             ]
    end

    test "delete" do
      values = [id: :float_test_delete, label: "Test float delete"]
      {:ok, unit} = create_param(:float, values)

      param = ParameterManager.get(values[:id], :test_schema)
      assert param.id == values[:id]

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert ParameterManager.get(values[:id], :test_schema) == get_msg(values[:id])
    end
  end

  describe "Boolean" do
    defp get_bool_opts(context),
      do: %{opts: [id: :boolean_test, label: "Test boolean", default_boolean: true]}

    setup [:get_bool_opts, :create_param, :check_arke, :check_parameter_node]

    test "create" do
      # Creation happens in the setup
      param = ParameterManager.get(:boolean_test, :test_schema)
      assert param.id == :boolean_test
    end

    test "associate" do
      parameter_model = ArkeManager.get(:boolean, :arke_system)

      QueryManager.create(:test_schema, parameter_model,
        id: :test_association_boolean,
        label: "Test Association boolean"
      )

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_boolean",
        "parameter",
        %{}
      )

      nodes = get_query_node(:test_association_boolean) |> QueryManager.all()
      unit = List.first(nodes)
      assert unit.data.parent_id == "test_arke_parameter"
      assert unit.data.child_id == "test_association_boolean"

      arke = ArkeManager.get(:test_arke_parameter, :test_schema)

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_boolean",
        "parameter",
        %{}
      )

      assert length(
               Enum.filter(ArkeManager.get_parameters(arke), fn p ->
                 p.id == :test_association_boolean
               end)
             ) > 0
    end

    test "create unit" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} = QueryManager.create(:test_schema, arke_model, %{label: "First boolean unit"})
      assert unit.data.boolean_test == true
    end

    test "create unit (error)" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)
      # FIXME:  validator should accept only true or false for boolean and not string nor number
      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          boolean_test: "string not valid",
          label: "First boolean unit"
        })

      assert unit == [%{context: "parameter_validation", message: "Test boolean: max is 5"}]
    end

    test "delete" do
      values = [id: :bool_test_delete, label: "Test boolean delete"]
      {:ok, unit} = create_param(:boolean, values)

      param = ParameterManager.get(values[:id], :test_schema)
      assert param.id == values[:id]

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert ParameterManager.get(values[:id], :test_schema) == get_msg(values[:id])
    end
  end

  describe "Dict" do
    defp get_dict_opts(context), do: %{opts: [id: :dict_test, label: "Test dict"]}
    setup [:get_dict_opts, :create_param, :check_arke, :check_parameter_node]

    test "create" do
      # Creation happens in the setup
      param = ParameterManager.get(:dict_test, :test_schema)
      assert param.id == :dict_test
    end

    test "associate" do
      parameter_model = ArkeManager.get(:dict, :arke_system)

      QueryManager.create(:test_schema, parameter_model,
        id: :test_association_dict,
        label: "Test Association dict"
      )

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_dict",
        "parameter",
        %{}
      )

      nodes = get_query_node(:test_association_dict) |> QueryManager.all()
      unit = List.first(nodes)
      assert unit.data.parent_id == "test_arke_parameter"
      assert unit.data.child_id == "test_association_dict"

      arke = ArkeManager.get(:test_arke_parameter, :test_schema)

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_dict",
        "parameter",
        %{}
      )

      assert length(
               Enum.filter(ArkeManager.get_parameters(arke), fn p ->
                 p.id == :test_association_dict
               end)
             ) >
               0
    end

    test "create unit" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          dict_test: %{"key" => "value"},
          label: "First dict unit"
        })

      assert unit.data.dict_test == %{"key" => "value"}
    end

    test "create unit (error)" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)
      # should accept only true/false
      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          dict_test: "string not valid",
          label: "First dict unit"
        })

      assert unit == [%{context: "parameter_validation", message: "Test dict: must be a map"}]
    end

    test "delete" do
      values = [id: :dict_test_delete, label: "Test dict delete"]
      {:ok, unit} = create_param(:dict, values)

      param = ParameterManager.get(values[:id], :test_schema)
      assert param.id == values[:id]

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert ParameterManager.get(values[:id], :test_schema) == get_msg(values[:id])
    end
  end

  describe "List" do
    defp get_list_opts(context), do: %{opts: [id: :list_test, label: "Test list"]}
    setup [:get_list_opts, :create_param, :check_arke, :check_parameter_node]

    test "create" do
      # Creation happens in the setup
      param = ParameterManager.get(:list_test, :test_schema)
      assert param.id == :list_test
    end

    test "associate" do
      parameter_model = ArkeManager.get(:list, :arke_system)

      QueryManager.create(:test_schema, parameter_model,
        id: :test_association_list,
        label: "Test Association list"
      )

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_list",
        "parameter",
        %{}
      )

      nodes = get_query_node(:test_association_list) |> QueryManager.all()
      unit = List.first(nodes)
      assert unit.data.parent_id == "test_arke_parameter"
      assert unit.data.child_id == "test_association_list"

      arke = ArkeManager.get(:test_arke_parameter, :test_schema)

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_list",
        "parameter",
        %{}
      )

      assert length(
               Enum.filter(ArkeManager.get_parameters(arke), fn p ->
                 p.id == :test_association_list
               end)
             ) >
               0
    end

    test "create unit" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          list_test: ["first value", 2, true],
          label: "First list unit"
        })

      assert unit.data.list_test == ["first value", 2, true]
    end

    test "create unit (error)" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)
      # should accept only true/false
      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          list_test: "string not valid",
          label: "First list unit"
        })

      assert unit == [%{context: "parameter_validation", message: "Test list: must be a list"}]
    end

    test "delete" do
      values = [id: :list_test_delete, label: "Test list delete"]
      {:ok, unit} = create_param(:list, values)

      param = ParameterManager.get(values[:id], :test_schema)
      assert param.id == values[:id]

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert ParameterManager.get(values[:id], :test_schema) == get_msg(values[:id])
    end
  end

  describe "Date" do
    defp get_date_opts(context), do: %{opts: [id: :date_test, label: "Test date"]}
    setup [:get_date_opts, :create_param, :check_arke, :check_parameter_node]

    test "create" do
      # Creation happens in the setup
      param = ParameterManager.get(:date_test, :test_schema)
      assert param.id == :date_test
    end

    test "associate" do
      parameter_model = ArkeManager.get(:date, :arke_system)

      QueryManager.create(:test_schema, parameter_model,
        id: :test_association_date,
        label: "Test Association date"
      )

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_date",
        "parameter",
        %{}
      )

      nodes = get_query_node(:test_association_date) |> QueryManager.all()
      unit = List.first(nodes)
      assert unit.data.parent_id == "test_arke_parameter"
      assert unit.data.child_id == "test_association_date"

      arke = ArkeManager.get(:test_arke_parameter, :test_schema)

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_date",
        "parameter",
        %{}
      )

      assert length(
               Enum.filter(ArkeManager.get_parameters(arke), fn p ->
                 p.id == :test_association_date
               end)
             ) >
               0
    end

    test "create unit" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          date_test: "1999-01-31",
          label: "First date unit"
        })

      assert unit.data.date_test == ~D[1999-01-31]

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          date_test: ~D[2000-04-25],
          label: "First date unit"
        })

      assert unit.data.date_test == ~D[2000-04-25]

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          date_test: %Date{day: 15, month: 11, year: 1993},
          label: "First date unit"
        })

      assert unit.data.date_test == ~D[1993-11-15]

      {:ok, date} = Date.new(1993, 11, 15)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{date_test: date, label: "First date unit"})

      assert unit.data.date_test == ~D[1993-11-15]
    end

    test "create unit (error)" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)
      # should accept only true/false
      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          date_test: "31-01-1999",
          label: "First date unit"
        })

      assert unit == [
               %{
                 context: "parameter_validation",
                 message: "Test date: must be iso8601 (YYYY-MM-DD) format"
               }
             ]
    end

    test "delete" do
      values = [id: :date_test_delete, label: "Test date delete"]
      {:ok, unit} = create_param(:date, values)

      param = ParameterManager.get(values[:id], :test_schema)
      assert param.id == values[:id]

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert ParameterManager.get(values[:id], :test_schema) == get_msg(values[:id])
    end
  end

  describe "Time" do
    defp get_time_opts(context), do: %{opts: [id: :time_test, label: "Test time"]}
    setup [:get_time_opts, :create_param, :check_arke, :check_parameter_node]

    test "create" do
      # Creation happens in the setup
      param = ParameterManager.get(:time_test, :test_schema)
      assert param.id == :time_test
    end

    test "associate" do
      parameter_model = ArkeManager.get(:time, :arke_system)

      QueryManager.create(:test_schema, parameter_model,
        id: :test_association_time,
        label: "Test Association time"
      )

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_time",
        "parameter",
        %{}
      )

      nodes = get_query_node(:test_association_time) |> QueryManager.all()
      unit = List.first(nodes)
      assert unit.data.parent_id == "test_arke_parameter"
      assert unit.data.child_id == "test_association_time"

      arke = ArkeManager.get(:test_arke_parameter, :test_schema)

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_time",
        "parameter",
        %{}
      )

      assert length(
               Enum.filter(ArkeManager.get_parameters(arke), fn p ->
                 p.id == :test_association_time
               end)
             ) >
               0
    end

    test "create unit" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          time_test: "23:59:12",
          label: "First time unit"
        })

      assert unit.data.time_test == ~T[23:59:12]

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          time_test: ~T[11:59:12],
          label: "First time unit"
        })

      assert unit.data.time_test == ~T[11:59:12]

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          time_test: %Time{second: 15, hour: 06, minute: 45},
          label: "First time unit"
        })

      assert unit.data.time_test == ~T[06:45:15]

      {:ok, time} = Time.new(06, 45, 15)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{time_test: time, label: "First time unit"})

      assert unit.data.time_test == ~T[06:45:15]
    end

    test "create unit (error)" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)
      # should accept only true/false
      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          time_test: "31-01-1999",
          label: "First time unit"
        })

      assert unit == [
               %{
                 context: "parameter_validation",
                 message: "Test time: must be iso8601 (HH:MM:SS) format"
               }
             ]
    end

    test "delete" do
      values = [id: :time_test_delete, label: "Test time delete"]
      {:ok, unit} = create_param(:time, values)

      param = ParameterManager.get(values[:id], :test_schema)
      assert param.id == values[:id]

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert ParameterManager.get(values[:id], :test_schema) == get_msg(values[:id])
    end
  end

  describe "DateTime" do
    defp get_datetime_opts(context), do: %{opts: [id: :datetime_test, label: "Test datetime"]}
    setup [:get_datetime_opts, :create_param, :check_arke, :check_parameter_node]

    test "create" do
      # Creation happens in the setup
      param = ParameterManager.get(:datetime_test, :test_schema)
      assert param.id == :datetime_test
    end

    test "associate" do
      parameter_model = ArkeManager.get(:datetime, :arke_system)

      QueryManager.create(:test_schema, parameter_model,
        id: :test_association_datetime,
        label: "Test Association datetime"
      )

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_datetime",
        "parameter",
        %{}
      )

      nodes = get_query_node(:test_association_datetime) |> QueryManager.all()
      unit = List.first(nodes)
      assert unit.data.parent_id == "test_arke_parameter"
      assert unit.data.child_id == "test_association_datetime"

      arke = ArkeManager.get(:test_arke_parameter, :test_schema)

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_datetime",
        "parameter",
        %{}
      )

      assert length(
               Enum.filter(ArkeManager.get_parameters(arke), fn p ->
                 p.id == :test_association_datetime
               end)
             ) > 0
    end

    test "create unit" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, date} = Date.new(1999, 01, 31)
      {:ok, time} = Time.new(23, 59, 12)
      {:ok, datetime} = DateTime.new(date, time)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          datetime_test: "1999-01-31 23:59:12",
          label: "First datetime unit"
        })

      assert unit.data.datetime_test == datetime

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          datetime_test: ~N[2000-01-31 23:59:12],
          label: "First datetime unit"
        })

      assert unit.data.datetime_test == ~U[2000-01-31 23:59:12Z]

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          datetime_test: ~U[1999-01-31 23:59:12Z],
          label: "First datetime unit"
        })

      assert unit.data.datetime_test == datetime

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          datetime_test: datetime,
          label: "First datetime unit"
        })

      assert unit.data.datetime_test == ~U[1999-01-31 23:59:12Z]
    end

    test "create unit (error)" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)
      # should accept only true/false
      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          datetime_test: "31-01-1999",
          label: "First datetime unit"
        })

      assert unit == [
               %{
                 context: "parameter_validation",
                 message:
                   "Test datetime: must be iso8601 (YYYY-MM-DDTHH:MM:SS or YYYY-MM-DD HH:MM:SS) format"
               }
             ]
    end

    test "delete" do
      values = [id: :datetime_test_delete, label: "Test datetime delete"]
      {:ok, unit} = create_param(:datetime, values)

      param = ParameterManager.get(values[:id], :test_schema)
      assert param.id == values[:id]

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert ParameterManager.get(values[:id], :test_schema) == get_msg(values[:id])
    end
  end

  describe "Link" do
    defp get_link_opts(context), do: %{opts: [id: :link_test, label: "Test link"]}
    setup [:get_link_opts, :create_param, :check_arke, :check_parameter_node]

    test "create" do
      # Creation happens in the setup
      param = ParameterManager.get(:link_test, :test_schema)
      assert param.id == :link_test
    end

    test "associate" do
      parameter_model = ArkeManager.get(:link, :arke_system)

      QueryManager.create(:test_schema, parameter_model,
        id: :test_association_link,
        label: "Test Association link"
      )

      LinkManager.add_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_link",
        "parameter",
        %{}
      )

      nodes = get_query_node(:test_association_link) |> QueryManager.all()
      unit = List.first(nodes)
      assert unit.data.parent_id == "test_arke_parameter"
      assert unit.data.child_id == "test_association_link"

      arke = ArkeManager.get(:test_arke_parameter, :test_schema)

      LinkManager.delete_node(
        :test_schema,
        "test_arke_parameter",
        "test_association_link",
        "parameter",
        %{}
      )

      assert length(
               Enum.filter(ArkeManager.get_parameters(arke), fn p ->
                 p.id == :test_association_link
               end)
             ) >
               0
    end

    test "create unit" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)

      {:ok, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          link_test: ["to define"],
          label: "First link unit"
        })

      assert unit.data.link_test == ["to define"]
    end

    test "create unit (error)" do
      arke_model = ArkeManager.get(:test_arke_parameter, :test_schema)
      # TODO: validator for link type
      {:error, unit} =
        QueryManager.create(:test_schema, arke_model, %{
          link_test: "31-01-1999",
          label: "First link unit"
        })

      assert unit == [
               %{context: "parameter_validation", message: "Test link: validator to define"}
             ]
    end

    test "delete" do
      values = [id: :link_test_delete, label: "Test link delete"]
      {:ok, unit} = create_param(:link, values)

      param = ParameterManager.get(values[:id], :test_schema)
      assert param.id == values[:id]

      QueryManager.delete(:test_schema, QueryManager.get_by(id: unit.id, project: :test_schema))

      assert ParameterManager.get(values[:id], :test_schema) == get_msg(values[:id])
    end
  end
end
