defmodule Arke.Example.System.MacroGroup do
  @moduledoc """
  List of all the available overridable functions in the `Arke.System.Group.__using__/1` macro. \n
  All the functions named `before_*` are executed after the overridable function of
  `Arke.System.__using__/1` while the ones with `on_*` are executed after.
  """
  use Arke.System.Group

  @doc """
  Overridable function in order to be able to edit data before the unit load
  ## Parameters
      - `arke` => Arke of the group we are preparing the load
      - `data` => All the data of the Unit we are loading
      - `persistence_fn` => Used to identify on which CRUD operations we are loading the unit, so we can pattern match it
  """
  @spec before_unit_load(arke :: %Arke.Core.Arke{},data :: %{atom => any()},persistence_fn :: :create | :update) :: {:ok, %{atom() => any}} | {:error, String.t()}
  def before_unit_load(_arke, data, _persistence_fn), do: {:ok, data}

  @doc """
  Overridable function in order to be able to edit data during the unit load
  ## Parameters
      - `arke` => Arke of the group we are permorming the load
      - `data` => All the data of the Unit we are loading
      - `persistence_fn` => Used to identify on which CRUD operations we are loading the unit, so we can pattern match it
  """
  @spec on_unit_load(arke :: %Arke.Core.Arke{},data :: %{atom => any()},persistence_fn :: :create | :update) :: {:ok, %{atom() => any}} | {:error, String.t()}
  def on_unit_load(_arke, data, _persistence_fn), do: {:ok, data}

  @doc """
  Overridable function in order to be able to edit data before the validation
  ## Parameters
      - `arke` => Arke we use as model to validate the parameter
      - `unit` => Unit we want to validate against the arke model
  """
  @spec before_unit_validate(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def before_unit_validate(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data during the validation
  ## Parameters
      - `arke` => Arke we used as model to validate the parameter
      - `unit` => Unit we have validated against the arke model
  """
  @spec on_unit_validate(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def on_unit_validate(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data before the creation
  ## Parameters
      - `arke` => Arke we use as model to create the Unit
      - `unit` => Unit we want to create
  """
  @spec before_unit_create(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def before_unit_create(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data during the creation
  ## Parameters
      - `arke` => Arke we used as model to create the Unit
      - `unit` => Unit we have just created
  """
  @spec on_unit_create(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def on_unit_create(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data during the encoding
  ## Parameters
      - `unit` => Unit we have just encoded
      - `arke` => Arke we used as model to encode the Unit struct
  """
  @spec on_unit_struct_encode(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def on_unit_struct_encode(unit, _arke), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data before the update
  ## Parameters
      - `arke` => Arke we use as model to update the Unit
      - `unit` => Unit before the update
  """
  @spec before_unit_update(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def before_unit_update(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data on the update
  ## Parameters
      - `arke` => Arke we use as model to update the Unit
      - `unit` => Unit after the update
  """
  @spec on_unit_update(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def on_unit_update(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data before the deletion
  ## Parameters
      - `arke` => Arke we use as model to delete the Unit
      - `unit` => Unit we want to delete
  """
  @spec before_unit_delete(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def before_unit_delete(_arke, unit), do: {:ok, unit}

  @doc """
  Overridable function in order to be able to edit data during the deletion
  ## Parameters
      - `arke` => Arke we used as model to delete the Unit
      - `unit` => Unit we have just deleted
  """
  @spec on_unit_delete(arke :: %Arke.Core.Arke{},unit :: %Arke.Core.Unit{}) :: {:ok, %Arke.Core.Unit{}} | {:error, String.t()}
  def on_unit_delete(_arke, unit), do: {:ok, unit}

end