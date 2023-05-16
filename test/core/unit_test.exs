defmodule Arke.Core.UnitTest do
  use Arke.RepoCase

  describe "Unit" do
    test "new" do
      # id, data, arke_id, link, metadata, inserted_at, updated_at, __module__
      now = Date.utc_today()

      # when is_atom(id)
      unit =
        Unit.new(:unit_test_id, [label: "Unit test id"], :arke, nil, %{}, now, now, __MODULE__)

      # when is_binary(id)
      unit_bin =
        Unit.new(:unit_test_id, [label: "Unit test id"], :arke, nil, %{}, now, now, __MODULE__)

      #
      unit_nil = Unit.new(12, [label: "Unit test id"], :arke, nil, %{}, now, now, __MODULE__)

      assert unit.id == :unit_test_id
      assert unit.arke_id == :arke
      assert unit_bin.id == :unit_test_id
      assert unit_bin.arke_id == :arke
      assert unit_nil.id == nil
      assert unit_nil.arke_id == :arke
    end

    test "load" do
      arke_model = ArkeManager.get(:arke, :arke_system)
      data = [id: :unit_test_id, label: "Unit test id"]

      # when is_list(opts)
      unit_list = Unit.load(arke_model, data)

      assert unit_list.id == :unit_test_id
      assert unit_list.arke_id == :arke

      # when opts metadata is nil
      data = [id: :unit_test_id, label: "Unit test id", metadata: nil]
      unit_list = Unit.load(arke_model, data)

      assert unit_list.id == :unit_test_id
      assert unit_list.metadata == arke_model.metadata

      # check default assignment
      arke_model = ArkeManager.get(:arke_test_support, :arke_system)

      unit_default = Unit.load(arke_model, [])

      assert unit_default.data.boolean_support == false
      assert unit_default.data.date_support == ~D[1999-11-08]
      assert unit_default.data.datetime_support == ~U[1999-11-08 09:55:13.416444Z]
      assert unit_default.data.dict_support == %{starting: "value"}
      assert unit_default.data.enum_float_support == nil
      assert unit_default.data.enum_integer_support == nil
      assert unit_default.data.enum_string_support == nil
      assert unit_default.data.float_support == 2.5
      assert unit_default.data.integer_support == 5
      assert unit_default.data.list_support == ["list", "of", "values"]
      assert unit_default.data.string_support == "test_default"
      assert unit_default.data.time_support == ~T[09:55:13.416444]

      # Generate unit with data

      datetime_now = DateTime.utc_now()
      date_now = Date.utc_today()
      time_now = Time.utc_now()

      unit_data = [
        boolean_support: true,
        date_support: date_now,
        datetime_support: datetime_now,
        dict_support: %{new: "value"},
        float_support: 4.5,
        integer_support: 10,
        list_support: ["edited", "value"],
        string_support: "new_value",
        time_support: time_now,
        enum_float_support: 3.5,
        enum_integer_support: [1, 4],
        enum_string_support: "second"
      ]

      unit = Unit.load(arke_model, unit_data)

      assert unit.data.boolean_support == true
      assert unit.data.date_support == date_now
      assert unit.data.datetime_support == datetime_now
      assert unit.data.dict_support == %{new: "value"}
      assert unit.data.enum_float_support == 3.5
      assert unit.data.enum_integer_support == [1, 4]
      assert unit.data.enum_string_support == "second"
      assert unit.data.float_support == 4.5
      assert unit.data.integer_support == 10
      assert unit.data.list_support == ["edited", "value"]
      assert unit.data.string_support == "new_value"
      assert unit.data.time_support == time_now
    end

    test "load_data" do
      arke_model = ArkeManager.get(:arke, :arke_system)
      data = %{id: :unit_test_id, label: "Unit test id"}

      unit_data = Unit.load_data(arke_model, %{}, data)

      assert unit_data.label == data.label
      assert unit_data.type == "arke"
      assert Map.get(unit_data, :id) == nil
    end

    test "update" do
      arke_model = ArkeManager.get(:arke_test_support, :arke_system)

      unit_default = Unit.load(arke_model, [])

      unit_updated =
        Unit.update(unit_default,
          float_support: 4.5,
          integer_support: 10,
          list_support: ["edited", "value"],
          string_support: "new_value"
        )

      assert unit_updated.data.float_support != unit_default.data.float_support
      assert unit_updated.data.integer_support != unit_default.data.integer_support
      assert unit_updated.data.list_support != unit_default.data.list_support
      assert unit_updated.data.string_support != unit_default.data.string_support
    end
  end
end
