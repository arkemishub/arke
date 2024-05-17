defmodule Arke.Example.SystemMacroFunction do
  @moduledoc"""
  Show all the available overridable functions in the `Arke.System` macro
  """
  use Arke.System
  @doc """
  Overridable function in order to be able to edit data during the  unit load
  """
  def on_load(data, _persistence_fn), do: {:ok, data}

  @doc """
  Overridable function in order to be able to edit data before the load
  """
  def before_load(data, _persistence_fn), do: {:ok, data}

  @doc """
  Overridable function in order to be able to edit data during the validation
  """
  def on_validate(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data before the validation
  """
  def before_validate(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data during the creation
  """
  def on_create(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data before the creation
  """
  def before_create(_arke, unit), do: {:ok, unit}
  @doc """
  Overridable function in order to be able to edit data during the encoding
  """
  def on_struct_encode(_, _, data, _opts), do: {:ok, data}
  @doc """
  Overridable function in order to be able to edit data before the encoding
  """
  def before_struct_encode(_, unit), do: {:ok, unit}
  @doc """
  Overridable function in order to be able to edit data on the update
  """
  def on_update(_arke, _old_unit, unit), do: {:ok, unit}
  @doc """
  Overridable function in order to be able to edit data before the update
  """
  def before_update(_arke, unit), do: {:ok, unit}
  @doc """
  Overridable function in order to be able to edit data during the deletion
  """
  def on_delete(_arke, unit), do: {:ok, unit}
  @doc """
  Overridable function in order to be able to edit data before the deletion
  """
  def before_delete(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data after the encoding
  """
  def after_get_struct(_arke, _unit, struct), do: struct
  def after_get_struct(_arke, struct), do: struct

  @doc """
  Overridable function used to import arkes from excel file
  """
  def import(%{runtime_data: %{conn: %{method: "POST"}=_conn}, metadata: %{project: _project}} = _arke), do:  {:ok, %{}, 201}

  @doc """
  Overridable function used to import units from excels files
  """
  defp import_units(_arke, _project, _member, _file, _mode), do: {:ok, %{}, 201}

  @doc """
  Overridable function used to get all the units that will be used in the import
  """
  defp get_all_units_for_import(_project), do: []

  @doc """
  Overridable function used to create Units struct from the data in an import file
  """
  defp load_units(_project, _arke, _header, _row, _, "default"), do: {:ok, []}
  @doc """
  Overridable function used to get all the units already created
  """
  defp get_existing_units_for_import(_project, _arke, _header, _units_args), do: []
  @doc """
  Overridable function used to check if all the units for the import are valid or not
  """
  defp check_existing_units_for_import(_project, _arke, _header, _units_args, _existing_units), do: true
  defp get_import_value(_header, _row, _column), do: ""

  @doc """
  Return the values of `Arke.Parameter.BaseParameter`
  """
  def base_parameters(), do: []
  @doc """
  Return the Arke struct for the given module
  """
  def arke_from_attr(), do: nil
  @doc """
  Return all the groups where the Arke, defined in the module, belongs to
  """
  def groups_from_attr(), do: []
end