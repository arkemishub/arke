defmodule StructManagerTest do
  use Arke.RepoCase

  defp get_parameter_list(),
    do: [:string, :integer, :float, :date, :time, :datetime, :dict, :list, :boolean]

  defp get_date() do
    {:ok, date} = Date.new(1999, 12, 30)
    date
  end

  defp get_time() do
    {:ok, time} = Time.new(23, 59, 15)
    time
  end

  defp get_datetime() do
    {:ok, datetime} = DateTime.new(get_date(), get_time())
    datetime
  end

  defp get_parameter_values_decode() do
    [
      label: "unit struct test",
      string_struct_test: "struct_test",
      integer_struct_test: 2,
      float_struct_test: 5.5,
      date_struct_test: "1999-12-30",
      time_struct_test: "23:59:15",
      datetime_struct_test: "2022-10-31T16:44:19",
      dict_struct_test: %{key: "value"},
      list_struct_test: ["list", "of", "values"],
      boolean_struct_test: true
    ]
  end

  defp get_parameter_values_encode() do
    [
      label: "unit struct test",
      string_struct_test: "struct_test",
      integer_struct_test: 2,
      float_struct_test: 5.5,
      date_struct_test: get_date(),
      time_struct_test: get_time(),
      datetime_struct_test: get_datetime(),
      dict_struct_test: %{key: "value"},
      list_struct_test: ["list", "of", "values"],
      boolean_struct_test: true
    ]
  end

  defp create_arke_test() do
    arke_model = ArkeManager.get(:arke, :arke_system)
    arke_opts = [id: "test_arke_struct", label: "test_arke_struct", active: true]
    QueryManager.create(:test_schema, arke_model, arke_opts)

    param_list = get_parameter_list()
    Enum.each(param_list, &create_param(&1))

    new_arke_model = ArkeManager.get(:test_arke_struct, :test_schema)
    values = get_parameter_values_encode()

    {:ok, unit} = QueryManager.create(:test_schema, new_arke_model, values)
  end

  defp clear_all() do
    parameter_list = get_parameter_list()

    unit = get_unit()
    QueryManager.delete(:test_schema, unit)

    Enum.each(
      parameter_list,
      &LinkManager.delete_node(
        :test_schema,
        "test_arke_struct",
        "#{&1}_struct_test",
        "parameter",
        %{}
      )
    )

    Enum.each(
      parameter_list,
      &QueryManager.delete(
        :test_schema,
        QueryManager.get_by(id: String.to_atom("#{&1}_struct_test"), project: :test_schema)
      )
    )

    QueryManager.delete(
      :test_schema,
      QueryManager.get_by(id: :test_arke_struct, project: :test_schema)
    )
  end

  defp get_unit() do
    unit =
      QueryManager.query(project: :test_schema)
      |> QueryManager.where(arke_id__eq: "test_arke_struct")
      |> QueryManager.one()
  end

  defp create_param(type) do
    parameter_model = ArkeManager.get(type, :arke_system)

    {:ok, unit} =
      QueryManager.create(:test_schema, parameter_model,
        id: "#{type}_struct_test",
        label: "#{String.upcase(to_string(type))} Struct Test Label"
      )

    LinkManager.add_node(
      :test_schema,
      "test_arke_struct",
      "#{type}_struct_test",
      "parameter",
      %{}
    )

    :ok
  end

  describe "StructManager" do
    test "encode" do
      create_arke_test()
      unit = get_unit()

      base_keys = [:id, :arke_id, :inserted_at, :updated_at, :metadata]

      # encode when is_list(unit)
      struct = StructManager.encode([unit], type: :json)
      keys = Enum.map(base_keys, fn k -> Map.has_key?(List.first(struct), k) end)

      assert Enum.all?(keys, &(&1 == true)) == true

      # encode
      struct = StructManager.encode(unit, type: :json)
      keys = Enum.map(base_keys, fn k -> Map.has_key?(struct, k) end)

      assert Enum.all?(keys, &(&1 == true)) == true
      # Means the keys from unit.data are in the struct
      assert Map.keys(struct) -- base_keys != []

      # encode error

      assert_raise RuntimeError, "Must pass a valid unit", fn ->
        StructManager.encode("invalid unit", type: :json)
      end

      # encode nil data

      unit_nil = Map.put_new(Map.delete(unit, :data), :data, nil)

      struct = StructManager.encode(unit_nil, type: :json)
      keys = Enum.map(base_keys, fn k -> Map.has_key?(struct, k) end)

      assert Map.keys(struct) -- base_keys == []

      # encode  unit data = %{}

      unit_nil = Map.put_new(Map.delete(unit, :data), :data, %{})

      struct = StructManager.encode(unit_nil, type: :json)
      keys = Enum.map(base_keys, fn k -> Map.has_key?(struct, k) end)

      assert Map.keys(struct) -- base_keys == []
    end

    test "decode" do
      create_arke_test()

      values = get_parameter_values_decode()

      # decode when is_atom(arke_id)
      struct = StructManager.decode(:test_schema, :test_arke_struct, values, :json)

      assert struct.__struct__ == Arke.Core.Unit
      assert struct.arke_id == :test_arke_struct
      assert struct.data.float_struct_test == 5.5

      # decode when is_string(arke_id)
      struct = StructManager.decode(:test_schema, "test_arke_struct", values, :json)

      ## TODO: try to decode date|datetime (maybe written with / instead of -) and time with invalid format and send error with message or not save

      assert struct.__struct__ == Arke.Core.Unit
      assert struct.arke_id == :test_arke_struct
      assert struct.data.integer_struct_test == 45

      clear_all()
    end

    test "get_struct" do
      create_arke_test()
      # get_struct with arke
      arke_model = ArkeManager.get(:arke, :arke_system)
      struct = StructManager.get_struct(arke_model)

      assert String.downcase(struct.label) == "arke"
      assert is_list(struct.parameters) == true
      assert length(struct.parameters) > 0

      test_arke = ArkeManager.get(:test_arke_struct, :test_schema)
      unit = get_unit()

      struct = StructManager.get_struct(test_arke, unit, [])

      param_with_value =
        Enum.find(struct.parameters, fn param -> param.id == "string_struct_test" end)

      assert param_with_value.value == "struct_test"

      clear_all()
    end
  end
end
