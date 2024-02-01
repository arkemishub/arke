# Copyright 2023 Arkemis S.r.l.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Arke.Core.Unit do
  @moduledoc """
    Struct which defines a Unit
        {arke_struct} = Unit
  """
  alias Arke.DatetimeHandler, as: DatetimeHandler
  alias Arke.Boundary.ArkeManager
  alias Arke.Utils.ErrorGenerator, as: Error

  defstruct ~w[id data arke_id link metadata inserted_at updated_at __module__ runtime_data]a

  def new(
        id,
        data,
        arke_id,
        link,
        metadata,
        inserted_at,
        updated_at,
        __module__,
        runtime_data \\ %{}
      ) do
    case check_id(id) do
      {:error, msg} ->
        {:error, msg}

      id ->
        __struct__(
          id: id,
          data: data,
          arke_id: arke_id,
          link: link,
          metadata: metadata,
          inserted_at: DatetimeHandler.parse_datetime(inserted_at, true),
          updated_at: DatetimeHandler.parse_datetime(updated_at, true),
          __module__: __module__,
          runtime_data: runtime_data
        )
    end
  end

  defp check_id(id) when is_binary(id), do: String.to_atom(id)
  defp check_id(id) when is_atom(id), do: id

  defp check_id(id) when is_number(id),
    do: Error.create(:parameter_validation, "id cannot be a number")

  defp check_id(_), do: nil

  defp check_metadata(metadata) when is_map(metadata) or is_nil(metadata), do: metadata
  defp check_metadata(_), do: Error.create(:parameter_validation, "metadata must be a map")

  def load(arke, opts, persistence_fn \\ :get)

  def load(arke, opts, persistence_fn) when is_list(opts),
    do: load(arke, Enum.into(opts, %{}), persistence_fn)

  def load(%{metadata: %{project: project}} = arke, %{metadata: nil} = opts, persistence_fn) do
    load(arke, Map.put(opts, :metadata, %{project: project}), persistence_fn)
  end

  def load(arke, opts, persistence_fn) do
    {id, opts} = Map.pop(opts, :id, nil)
    {link, opts} = get_link(opts)
    {metadata, opts} = Map.pop(opts, :metadata, arke.metadata)

    case check_metadata(metadata) do
      {:error, msg} ->
        {:error, msg}

      metadata ->
        {inserted_at, opts} = Map.pop(opts, :inserted_at, nil)
        {updated_at, opts} = Map.pop(opts, :updated_at, nil)
        {__module__, opts} = Map.pop(opts, :__module__, nil)
        {runtime_data, opts} = Map.pop(opts, :runtime_data, %{})

        with {:ok, opts} <- ArkeManager.call_func(arke, :before_load, [opts, persistence_fn]) do
          data = load_data(arke, %{}, opts)

          new(
            id,
            data,
            arke.id,
            link,
            metadata,
            inserted_at,
            updated_at,
            __module__,
            runtime_data
          )
        end
    end
  end

  def load_data(%{data: %{parameters: parameters}} = arke, unit_data, opts) do
    Enum.reduce(ArkeManager.get_parameters(arke), unit_data, fn %{
                                                                  id: parameter_id,
                                                                  arke_id: parameter_type
                                                                } = parameter,
                                                                new_unit_data ->
      load_parameter_value(parameter, new_unit_data, opts)
    end)
  end

  def load_parameter_value(%{id: :id} = _, data, opts), do: data
  def load_parameter_value(%{id: :metadata} = _, data, opts), do: data
  def load_parameter_value(%{id: :metadata} = _, data, opts), do: data
  def load_parameter_value(%{id: :arke_id} = _, data, opts), do: data
  def load_parameter_value(%{id: :inserted_at} = _, data, opts), do: data
  def load_parameter_value(%{id: :updated_at} = _, data, opts), do: data

  def load_parameter_value(%{id: parameter_id, arke_id: parameter_type} = parameter, data, opts) do
    value =
      get_data_value(Map.get(opts, parameter_id, nil))
      |> get_default_value(parameter)
      |> parse_value(parameter_type)

    Map.put_new(data, parameter_id, value)
  end

  def get_default_value(value, parameter) when is_nil(value), do: handle_default_value(parameter)
  def get_default_value(value, parameter), do: value

  defp handle_default_value(%{arke_id: :string, data: %{default_string: default_string}} = _),
    do: default_string

  defp handle_default_value(%{arke_id: :integer, data: %{default_integer: default_integer}} = _),
    do: default_integer

  defp handle_default_value(%{arke_id: :float, data: %{default_float: default_float}} = _),
    do: default_float

  defp handle_default_value(%{arke_id: :boolean, data: %{default_boolean: default_boolean}} = _),
    do: default_boolean

  defp handle_default_value(%{arke_id: :date, data: %{default_date: default_date}} = _),
    do: default_date

  defp handle_default_value(%{arke_id: :time, data: %{default_time: default_time}} = _),
    do: default_time

  defp handle_default_value(
         %{arke_id: :datetime, data: %{default_datetime: default_datetime}} = _
       ),
       do: default_datetime

  defp handle_default_value(%{arke_id: :dict, data: %{default_dict: default_dict}} = _),
    do: default_dict

  defp handle_default_value(%{arke_id: :list, data: %{default_list: default_list}} = _),
    do: default_list

  defp handle_default_value(%{arke_id: :link, data: %{default_link: default_link}} = _),
    do: default_link

  defp handle_default_value(_), do: nil

  defp get_link(%{depth: depth, link_metadata: link_metadata} = args),
    do: {%{depth: depth, metadata: link_metadata}, args}

  defp get_link(args), do: {nil, args}

  # Bae operations
  @doc """
  Edit and update a Unit by passing the Unit itself and the new data

  ## Example
      iex> arke = Arke.Boundary.ArkeManager.get(:arke, :arke_system)
      ...> unit = Arke.Core.Unit.generate(arke,%{id: :test, label: "Test"})
      ...> Arke.Core.Unit.update(unit, [label: "Test updated"] )

   ## Return
       %Arke.Core.Unit{}

  """
  @spec update(unit :: %Arke.Core.Unit{}, args :: [key: any()] | map()) :: %Arke.Core.Unit{}
  def update(unit, args) when is_list(args), do: update(unit, Enum.into(args, %{}))
  def update(unit, %{metadata: nil} = args), do: update(unit, Map.replace(args, :metadata, %{}))

  def update(unit, %{metadata: metadata} = args) when is_list(metadata),
    do: update(unit, Map.replace(args, :metadata, Enum.into(metadata, %{})))

  def update(%{data: data, arke_id: arke_id} = unit, args) do
    {id, args} = Map.pop(args, :id, unit.id)
    {link, args} = Map.pop(args, :link, unit.link)
    {metadata, args} = Map.pop(args, :metadata, unit.metadata)

    case check_metadata(metadata) do
      {:error, msg} ->
        {:error, msg}

      # todo: remove arke_system default once every arke is set on db
      metadata ->
        metadata = Map.put_new(metadata, :project, Map.get(metadata, :project, :arke_system))
        {inserted_at, args} = Map.pop(args, :inserted_at, unit.inserted_at)
        {updated_at, args} = Map.pop(args, :updated_at, unit.updated_at)
        {module, args} = Map.pop(args, :__module__, unit.__module__)
        {runtime_data, args} = Map.pop(args, :runtime_data, unit.runtime_data)

        data =
          Enum.reduce(args, data, fn {key, val}, new_data ->
            update_data(new_data, key, val)
          end)

        new(id, data, arke_id, link, metadata, inserted_at, updated_at, module, runtime_data)
    end
  end

  defp update_data(data, key, value) when is_atom(key), do: Map.put(data, key, value)

  defp update_data(data, key, value) when is_binary(key),
    do: Map.put(data, String.to_existing_atom(key), value)

  defp update_data(data, _key, _value), do: data

  # Handle parameters
  @doc """
  Get the Unit data as a keyword list

  ## Parameters
    - unit => %Arke.Core.Unit{} => the Unit itself

  ## Example
      iex> arke = Arke.Boundary.ArkeManager.get(:arke, :arke_system)
      ...> unit = Arke.Core.Unit.generate(arke,%{id: :test, label: "Test"})
      ...> data_string = Enum.map(unit.data, fn({key, value}) -> {Atom.to_string(key), value} end)
      ...> Arke.Core.Unit.data_as_klist(%{arke: unit.arke, data: data_string})

  ## Return
      [keyword: value]

  """
  @spec data_as_klist(unit :: %Arke.Core.Unit{}) :: [key: any()]
  def data_as_klist(%{arke: _arke, data: data} = _unit) do
    Enum.map(data, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end

  # defp add_parameters(%{arke: arke, data: data, link: link} = _unit, args) do
  #   data =
  #     Enum.reduce(arke.parameters, data, fn parameter, new_struct ->
  #       value = get_value(args, parameter.id) |> parse_value(parameter.type)
  #       add_parameter(new_struct, parameter, value)
  #     end)

  #   __struct__(arke: arke, data: data, link: link)
  # end

  # defp add_parameter(data, parameter, value) do
  #   Map.put_new(data, parameter.id, value)
  # end

  @doc """
  Get the value for the given data based on a key to search. Return the value to be assigned in the `generate` function

  ## Parameters
    - data = map | keyword => data to be parsed
    - key => :atom => key to search in the data

  ## Example
      iex> arke = Arke.Boundary.ArkeManager.get(:arke, :arke_system)
      ...> unit = Arke.Core.Unit.generate(arke,%{id: :test, label: "Test"})
      ...> Arke.Core.Unit.get_value(unit.data, :label)

  ## Return
      value

  """
  @spec get_value(data :: %Arke.Core.Unit{}, arg2 :: atom() | String.t()) ::
          String.t() | boolean() | number() | list() | %{}
  def get_value(%Arke.Core.Unit{data: data} = unit, parameter_id),
    do: get_value(data, parameter_id)

  def get_value(data, parameter_id) when is_map(data) and is_atom(parameter_id) do
    get_data_value(Map.get(data, parameter_id, nil))
  end

  def get_value(data, parameter_id) when is_map(data) and is_binary(parameter_id) do
    get_data_value(Map.get(data, String.to_existing_atom(parameter_id), nil))
  end

  def get_value(data, _parameter_id) when is_nil(data), do: {:error, "data can not be nil"}
  def get_value(data, parameter_id), do: Keyword.get(data, parameter_id, nil)

  @doc """
  Parse value to atom
  ## Parameter
    - value => string | any => value to parse
    - arg => :atom | any => if atom the string will be converted to atom if not it will be returned same as given

  ## Example
      iex> Arke.Core.Unit.parse_value("label", :atom)

  ## Return
      :value
  """
  @spec parse_value(
          value :: String.t() | boolean() | number() | list() | %{} | Date.t(),
          String.t()
        ) :: String.t() | boolean() | number() | list() | %{}
  defp parse_value(value, :atom) when is_binary(value), do: String.to_existing_atom(value)

  defp parse_value(value, :date) do
    with {:ok, date} <- DatetimeHandler.parse_date(value),
         do: date,
         else: ({:error, msg} -> to_string(msg))
  end

  defp parse_value(value, :time) do
    with {:ok, time} <- DatetimeHandler.parse_time(value),
         do: time,
         else: ({:error, msg} -> to_string(msg))
  end

  defp parse_value(value, :datetime) do
    with {:ok, datetime} <- DatetimeHandler.parse_datetime(value),
         do: datetime,
         else: ({:error, msg} -> to_string(msg))
  end

  defp parse_value(value, :boolean) do
    case value do
      "true" -> true
      "True" -> true
      "1" -> true
      1 -> true
      "false" -> false
      "False" -> false
      "0" -> false
      0 -> true
      _ -> value
    end
  end

  defp parse_value(value, _), do: value

  defp get_data_value(%{"datetime" => datetime, "value" => value} = _), do: value
  defp get_data_value(value), do: value

  @doc """
  Get data of all the given units

  ## Parameter
    - units => [ %Arke.Core.Unit{}, ....] => all the units from which we want to get data

  ## Example
      iex> arke = Arke.Boundary.ArkeManager.get(:arke, :arke_system)
      ... > unit1 = Arke.Core.Unit.generate(arke,%{id: :test, label: "Test"})
      ... > unit2 = Arke.Core.Unit.generate(arke,%{id: :test2, label: "Test2"})
      ... > Arke.Core.Unit.get_data([unit1, unit2])

  ## Return
      [%{data unit1}, %{data unit2}]
  """
  @spec get_data(units :: [%Arke.Core.Unit{}]) :: [%{}]
  def get_data(units) do
    Enum.reduce(units, [], fn %{arke: _arke, data: data}, list_data ->
      [data | list_data]
    end)
  end
end
