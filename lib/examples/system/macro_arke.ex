defmodule Arke.Example.System.MacroArke do
  @moduledoc"""
    List of all the available overridable functions in the `Arke.System.__using__/1` macro. \n
    All the functions named `before_*` are executed before the overridable function of
    `Arke.System.Group.__using__/1` while the ones with `on_*` are executed before.
  """
  use Arke.System


  @doc """
  Overridable function in order to be able to manage the data before the load.
  ## Parameters
      - `data` => All the data of the Unit we are loading
      - `persistence_fn` => Used to identify on which CRUD operations we are loading the unit, so we can pattern match it
  """
  @spec before_load(data :: %{atom() => any},persistence_fn :: :create | :update) :: {:ok, %{atom() => any}} | {:error, String.t()}
  def before_load(data, _persistence_fn), do: {:ok, data}

  @doc """
  Overridable function in order to be able to manage the data during the unit load
  ## Parameters
    - `data` => All the data of the Unit we are loading
    - `persistence_fn` => Used to identify on which CRUD operations we are loading the unit, so we can pattern match it
  """
  @spec on_load(data :: %{atom => any()},persistence_fn :: :create | :update) :: {:ok, %{atom() => any}} | {:error, String.t()}
  def on_load(data, _persistence_fn), do: {:ok, data}

  @doc """
  Overridable function in order to be able to manage the data before the validation
  ## Parameters
      - `arke` => Arke we use as model to validate the parameter
      - `unit` => Unit we want to validate against the arke model
  """
  @spec before_validate(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def before_validate(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to manage the data right after the validation
  ## Parameters
      - `arke` => Arke we used as model to validate the parameter
      - `unit` => Unit we have validated against the arke model
  """
  @spec on_validate(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def on_validate(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to manage the data before the creation
  ## Parameters
      - `arke` => Arke we use as model to create the Unit
      - `unit` => Unit we want to create
  """
  @spec before_create(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def before_create(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to right after the creation
  ## Parameters
      - `arke` => Arke we used as model to create the Unit
      - `unit` => Unit we have just created
  """
  @spec on_create(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def on_create(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to manage the data before the encoding
  ## Parameters
      - `arke` => Arke we uses as model to encode the Unit struct
      - `unit` => Unit we want to encode
  """
  @spec before_struct_encode(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def before_struct_encode(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit right after the encoding
  ## Parameters
      - `arke` => Arke we used as model to encode the Unit struct
      - `unit` => Unit we have just encoded
      - `data` => Data we want to encode
      - opts => List of options
  """
  @spec on_struct_encode(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{},data :: %{atom() => any} | %{}, opts :: [] | [...]) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def on_struct_encode(_arke, _unit, data, _opts), do: {:ok, data}

  @doc """
  Overridable function in order to be able to manage the data before the update
  ## Parameters
      - `arke` => Arke we use as model to update the Unit
      - `unit` => Unit we want to update
  """
  @spec before_update(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def before_update(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to manage the data on the update
  ## Parameters
      - `arke` => Arke we use as model to update the Unit
      - old_`unit` => Unit before the update
      - `unit` => Unit after the update
  """
  @spec on_update(arke :: %Arke.Core.Arke{},old_unit :: %Arke.Core.Unit{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def on_update(_arke, _old_unit, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to manage the data before the deletion
  ## Parameters
      - `arke` => Arke we use as model to delete the Unit
      - `unit` => Unit we want to delete
  """
  @spec before_delete(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def before_delete(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to manage the data during the deletion
  ## Parameters
      - `arke` => Arke we used as model to delete the Unit
      - `unit` => Unit we have just deleted
  """
  @spec on_delete(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def on_delete(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to manage the data of the Unit after the encoding
  ## Parameters
      - `arke` => Arke we used as model to delete the Unit
      - `unit` => Unit we have just deleted
      - `struct` => New struct of the unit
  """
  @spec after_get_struct(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{},struct:: %Arke.Core.Unit{}) :: %Arke.Core.Unit{}
  def after_get_struct(_arke, _unit, struct), do: struct

  @doc """
  Overridable function in order to be able to manage the data of the Arke after the encoding
  ## Parameters
      - `arke` => Arke we used as model to delete the Unit
      - `struct` => New struct of the Arke
  """
  @spec after_get_struct(arke :: %Arke.Core.Arke{},struct:: %Arke.Core.Unit{}) :: %Arke.Core.Arke{}
  def after_get_struct(_arke, struct), do: struct

  @doc """
  Overridable function used to import arkes from Excel file
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
  @spec base_parameters() :: [Arke.Parameter.BaseParameter.t()] | []
  def base_parameters(), do: []

end