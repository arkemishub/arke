defmodule Arke.Utils.ErrorGeneratorTest do
  use ExUnit.Case

  test "Arke.Utils.ErrorGenerator.create/2 when is_list" do
    errors = ["label is required", "username invalid"]

    assert Arke.Utils.ErrorGenerator.create(:test, errors) ==
             {:error,
              [
                %{context: "test", message: "label is required"},
                %{context: "test", message: "username invalid"}
              ]}
  end

  # PARAMETER VALIDATION ERROR FORMAT
  test "Arke.Utils.ErrorGenerator.create/2 when is_list(values)" do
    errors = [
      {"Max", "must be an integer"},
      {"allowed values for type are", ["customer", "admin", "super_admin"]}
    ]

    assert Arke.Utils.ErrorGenerator.create(:test, errors) ==
             {:error,
              [
                %{context: "test", message: "Max: must be an integer"},
                %{
                  context: "test",
                  message: "allowed values for type are: customer, admin, super_admin"
                }
              ]}
  end

  test "Arke.Utils.ErrorGenerator.create/2 when is_binary" do
    errors = "label must be a string"

    assert Arke.Utils.ErrorGenerator.create(:test, errors) ==
             {:error, [%{context: "test", message: "label must be a string"}]}
  end

  test "Arke.Utils.ErrorGenerator.create/2 invalid format" do
    errors = {12, [{"Label", "must be a string"}]}

    assert Arke.Utils.ErrorGenerator.create(:test, errors) ==
             {:error, [%{context: "error_generator", message: "invalid attribute format"}]}
  end
end
