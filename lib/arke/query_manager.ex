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

defmodule Arke.QueryManager do
  @moduledoc """
  Module to manage the CRUD operations to create the below `Elements` and also manage the query to get the elements from db.

  ## `Elements`
    - Parameter -> `Arke.Core.Parameter`
    - Arke -> `Arke.Core.Arke`
    - Unit -> `Arke.Core.Unit`
    - Group -> `Arke.Core.Group`
    - Link -> `Arke.Core.Link`
  ## `Operators`
    - `eq` -> equal -> `=`
    - `contains` -> contains a value (Case sensitive) ->  `LIKE %word%`
    - `icontains` -> contains a value (Not case sensitive) -> `ILIKE %word%`
    - `startswith` -> starts with the given value (Case sensitive) -> `LIKE %word`
    - `istartswith` -> starts with the given value (Not case sensitive) -> `ILIKE %word`
    - `endswith` -> ends with the given value (Case sensitive) -> `LIKE word%`
    - `iendswith` -> ends with the given value (Not case sensitive) -> `ILIKE word%`
    - `lte` -> less than or equal -> `<=`
    - `lt` -> less than -> `<`
    - `gt` -> greater than -> `>`
    - `gte` -> greater than or equal -> `>=`
    - `in` ->  value is in a collection -> `IN`
    - `isnull` -> value is_nil -> `IS NULL`

  """
  alias Arke.Boundary.{ArkeManager, ParameterManager, GroupManager}
  alias Arke.Validator
  alias Arke.LinkManager
  alias Arke.QueryManager
  alias Arke.Utils.DatetimeHandler, as: DatetimeHandler
  alias Arke.Core.{Arke, Unit, Query, Parameter}


  @persistence Application.get_env(:arke, :persistence)
  @record_fields [:id, :data, :metadata, :inserted_at, :updated_at]

  @type func_return() :: {:ok, %Unit{}} | Error.t()
  @type operator() ::
          :eq
          | :contains
          | :icontains
          | :startswith
          | :istartswith
          | :endswith
          | :iendswith
          | :lte
          | :lt
          | :gt
          | :gte
          | :in
          | :isnull

  @doc """
  Create a new query
  """
  @spec query(opts :: [project: String.t() | atom()]) ::
          Query.t()
  def query(opts) do
    project = Keyword.get(opts, :project)
    arke = get_arke(Keyword.get(opts, :arke), project)
    query = Query.new(arke, project)
  end

  @doc """
  Create a new topology query. It will get all the units related to the first one

  ## Parameter
    - `query` -> refer to `query/1`
    - `unit` -> struct of the unit used as reference for the query
    - `opts` -> KeywordList containing the link conditions
      - `depth`  max depth of the recursion.
      - `direction` --> the direction of the link. One of `child` or `parent`
      - `connection_type`  -> name of the connection to search
  """

  @spec link(
          Query.t(),
          unit :: %Unit{},
          opts :: [direction: :child | :parent, depth: integer(), type: String.t()]
        ) :: Query.t()
  def link(query, unit, opts \\ []) do
    direction = Keyword.get(opts, :direction, :child)
    depth = Keyword.get(opts, :depth, 500)
    type = Keyword.get(opts, :type, nil)

    query
    |> Query.add_link_filter(unit, parse_link_depth(depth), parse_link_direction(direction), type)
  end

  defp parse_link_depth(depth) when is_binary(depth), do: String.to_integer(depth)
  defp parse_link_depth(depth) when is_integer(depth), do: depth

  # TODO exception if depth is not an integer
  defp parse_link_depth(depth), do: 500

  defp parse_link_direction(direction) when is_binary(direction),
    do: String.to_existing_atom(direction)

  defp parse_link_direction(direction), do: direction

  @doc """
  Function to create a Unit. It will load a Unit based on the given arke, which is used as a model, and the given data.
  ## Parameters
    - `project` ->  identify the `Arke.Core.Project`
    - `arke` ->  identify the struct of the element we want to create
    - `args` ->  the data of the new element we want to create
  """
  @spec create(project :: atom(), arke :: %Arke{}, args :: [...]) :: func_return()
  def create(project, arke, args) do
    persistence_fn = @persistence[:arke_postgres][:create]
    with %Unit{} = unit <- Unit.load(arke, args, :create),
         {:ok, unit} <- Validator.validate(unit, :create, project),
         {:ok, unit} <- ArkeManager.call_func(arke, :before_create, [arke, unit]),
         {:ok, unit} <- handle_group_call_func(arke, unit, :before_unit_create),
         {:ok, unit} <- handle_link_parameters_unit(arke, unit),
         {:ok, unit} <- persistence_fn.(project, unit),
         {:ok, unit} <- ArkeManager.call_func(arke, :on_create, [arke, unit]),
         {:ok, unit} <- handle_link_parameters(unit, %{}),
         {:ok, unit} <- handle_group_call_func(arke, unit, :on_unit_create),
         do: {:ok, unit},
         else: ({:error, errors} -> {:error, errors})
  end

  defp handle_link_parameters_unit(%{id: :arke_link} = _, unit), do: {:ok, unit}

  defp handle_link_parameters_unit(
         %{data: parameters} = arke,
         %{metadata: %{project: project}} = unit
       ) do


    {errors, link_units} =
      Enum.filter(ArkeManager.get_parameters(arke), fn p -> p.arke_id == :link end)
      |> Enum.reduce({[], []}, fn p, {errors, link_units} ->

        arke = ArkeManager.get(String.to_existing_atom(p.data.arke_or_group_id), project)

        case handle_create_on_link_parameters_unit(
               project,
               unit,
               p,
               arke,
               Unit.get_value(unit, p.id)
             ) do
          {:ok, parameter, %Unit{} = link_unit} -> {errors, [{parameter, link_unit} | link_units]}
          {:ok, parameter, link_unit} -> {errors, link_units}
          {:error, e} -> {[e | errors], link_units}
        end
      end)

    case length(errors) > 0 do
      true ->
        Enum.map(link_units, fn {p, u} ->
          delete(project, u)
        end)

        {:error, errors}

      false ->
        args =
          Enum.reduce(link_units, %{}, fn {p, u}, args ->
            Map.put(args, p.id, Atom.to_string(u.id))
          end)

        {:ok, Unit.update(unit, args)}
    end
  end

  defp handle_create_on_link_parameters_unit(project, unit, parameter, arke, value)
       when is_nil(value),
       do: {:ok, parameter, value}

  defp handle_create_on_link_parameters_unit(project, unit, parameter, arke, value)
       when is_binary(value),
       do: {:ok, parameter, value}

  defp handle_create_on_link_parameters_unit(project, unit, parameter, arke, value)
       when is_map(value) do
    value = Map.put(value, :runtime_data, %{link: unit, link_parameter: parameter})

    case create(project, arke, value) do
      {:ok, unit} -> {:ok, parameter, unit}
      {:error, error} -> {:error, error}
    end
  end

  defp handle_create_on_link_parameters_unit(_, _, parameter, _, value),
    do: {:ok, parameter, value}

  def handle_group_call_func(arke, unit, func) do

    GroupManager.get_groups_by_arke(arke)
    |> Enum.reduce_while(unit, fn group, new_unit ->
      with {:ok, new_unit} <- GroupManager.call_func(group, func, [arke, new_unit]),
           do: {:cont, new_unit},
           else: ({:error, errors} -> {:halt, {:error, errors}})
    end)
    |> check_group_manager_functions_errors()
  end

  def check_group_manager_functions_errors({:error, errors} = _), do: {:error, errors}
  def check_group_manager_functions_errors(unit), do: {:ok, unit}

  @doc """
  Function to update a Unit.

  ## Parameters
    - `project` -> identify the `Arke.Core.Project`
    - `unit` ->  unit to update
    - `args` -> list of key: value to update

  """
  @spec update(%Unit{}, args :: list()) :: func_return()
  def update(%{arke_id: arke_id, metadata: %{project: project}, data: data} = current_unit, args) do
    persistence_fn = @persistence[:arke_postgres][:update]
    arke = ArkeManager.get(arke_id, project)
    with %Unit{} = unit <- Unit.update(current_unit, args),
         {:ok, unit} <- update_at_on_update(unit),
         {:ok, unit} <- Validator.validate(unit, :update, project),
         {:ok, unit} <- ArkeManager.call_func(arke, :before_update, [arke, unit]),
         {:ok, unit} <- handle_group_call_func(arke, unit, :before_unit_update),
         {:ok, unit} <- handle_link_parameters_unit(arke, unit),
         {:ok, unit} <- persistence_fn.(project, unit),
         {:ok, unit} <- ArkeManager.call_func(arke, :on_update, [arke, current_unit, unit]),
         {:ok, unit} <- handle_link_parameters(unit, data),
         {:ok, unit} <- handle_group_call_func(arke, unit, :on_unit_update),
         do: {:ok, unit},
         else: ({:error, errors} -> {:error, errors})
  end
  defp update_at_on_update(unit) do
    updated_at = DatetimeHandler.now(:datetime)
    {:ok, Unit.update(unit, updated_at: updated_at)}
  end
  @doc """
  Function to delete a given unit. It will delete the manager, if any, and the db record
  ## Parameters
    - `project` ->  identify the `Arke.Core.Project`
    - `unit` -> the unit to delete
  """
  @spec delete(project :: atom(), %Unit{}) :: {:ok, any()}
  def delete(project, %{arke_id: arke_id} = unit) do
    arke = ArkeManager.get(arke_id, project)
    persistence_fn = @persistence[:arke_postgres][:delete]

    with {:ok, unit} <- ArkeManager.call_func(arke, :before_delete, [arke, unit]),
         {:ok, unit} <- handle_group_call_func(arke, unit, :before_unit_delete),
         {:ok, nil} <- persistence_fn.(project, unit),
         {:ok, unit} <- handle_group_call_func(arke, unit, :on_unit_delete),
         {:ok, _unit} <- ArkeManager.call_func(arke, :on_delete, [arke, unit]),
         do: {:ok, nil},
         else: ({:error, errors} -> {:error, errors})
  end

  @doc """
  Create a query which is used to get a single element which match the given criteria.
  If more are returned then an exception will be raised
  """
  @spec get_by(opts :: [{:project,atom} | {atom,any}]) :: %Unit{} | nil
  def get_by(opts \\ []), do: basic_query(opts) |> one

  @doc """
  Create a query which is used to get all the element which match the given criteria
  """
  @spec filter_by(opts :: [{:project,atom} | {atom,any}]) :: [%Unit{}] | []
  def filter_by(opts \\ []), do: basic_query(opts) |> all
  defp basic_query(opts) when is_map(opts), do: Map.to_list(opts) |> basic_query

  defp basic_query(opts) do
    {project, opts} = Keyword.pop!(opts, :project)
    {arke, opts} = Keyword.pop(opts, :arke, nil)

    arke = get_arke(arke, project)

    query(project: project, arke: arke) |> where(opts)
  end

  defp get_arke(nil, _), do: nil

  defp get_arke(arke, project) when is_binary(arke),
    do: String.to_existing_atom(arke) |> get_arke(project)

  defp get_arke(arke, project) when is_atom(arke), do: ArkeManager.get(arke, project)
  defp get_arke(arke, _), do: arke

  defp get_group(group, project) when is_binary(group),
    do: String.to_existing_atom(group) |> get_group(project)

  defp get_group(group, project) when is_atom(group), do: GroupManager.get(group, project)
  defp get_group(group, _), do: group

  @doc """
  Add an `:and` logic to a query

  ## Parameter
    - query -> refer to `query/1`
    - negate -> boolean -> used to figure out whether the condition is to be denied
    - filters -> refer to `condition/3 | conditions/1`

  ## Example
      iex> query = QueryManager.query(arke: nil, project: :arke_system)
      ...> query = QueryManager.and_(query, false, QueryManager.conditions(parameter__eq: "value"))
  """
  @spec and_(query :: Query.t(), negate :: boolean(), filters :: list()) :: Query.t()
  def and_(query, negate, filters) when is_list(filters),
    do: Query.add_filter(query, :and, negate, parse_base_filters(query, filters))

  def and_(_query, _negate, filters), do: raise("filters must be a list")

  @doc """
  Add an `:or` logic to a query

  ## Parameter
    - query -> refer to `query/1`
    - negate -> boolean -> used to figure out whether the condition is to be denied
    - filters -> refer to `condition/3 | conditions/1`

  ## Example
      iex> query = QueryManager.query(arke: nil, project: :arke_system)
      ...> query = QueryManager.or_(query, false, QueryManager.conditions(parameter__eq: "value"))

  """
  @spec or_(query :: Query.t(), negate :: boolean(), filters :: list()) :: Query.t()
  def or_(query, negate, filters) when is_list(filters),
    do: Query.add_filter(query, :or, negate, parse_base_filters(query, filters))

  def or_(_query, _negate, filters), do: raise("filters must be a list")

  defp parse_base_filters(query, filters) do
    Enum.reduce(filters, [], fn f, new_filters ->
      parameter = get_parameter(query, f.parameter)
      [Query.new_base_filter(parameter, f.operator, f.value, f.negate) | new_filters]
    end)
  end

  @doc """
  Create a `Arke.Core.Query.BaseFilter`

  ## Parameters
    - `parameter` -> the parameter where to check the condition
    - `operator` -> refer to [operators](#module-operators)
    - `value` -> it will be parsed against the parameter type else it will return an error.
    - `negate` -> used to figure out whether the condition is to be denied

  ## Example
      iex> QueryManager.condition(:string, :eq, "test")
  """
  @spec condition(
          parameter :: %Unit{},
          negate :: boolean(),
          value :: String.t() | boolean() | number() | nil,
          negate :: boolean()
        ) :: Query.BaseFilter.t()
  def condition(parameter, operator, value, negate \\ false),
    do: Query.new_base_filter(parameter, operator, value, negate)

  @doc """
  Create a list of `Arke.Core.Query.BaseFilter`

  ## Parameter
    - `opts` -> the condtions used to create the BaseFilters.
    The key of the opts must be written as: parameter__operator

  ## Example
      iex>  QueryManager.conditions(name__eq: "test", string__contains: "t")
  """
  @spec conditions(opts :: list()) :: [Query.BaseFilter.t()]
  def conditions(opts \\ []) do
    Enum.reduce(opts, [], fn {key, value}, filters ->
      {parameter, operator} = get_parameter_operator(nil, String.split(Atom.to_string(key), "__"))
      [condition(parameter, operator, value) | filters]
    end)
  end

  @doc """
  Create query with specific filter. For the `opts` refer to `conditions/1`

  ##  Parameters
    - `query` -> refer to `query/1`
    - `opts` -> keyword list containing the filter to apply

  ## Example
      iex> query = Arke.QueryManager.query()
      ...> QueryManager.where(query, [id__contains: "me", id__contains: "n"])
  """
  @spec where(query :: Query.t(), opts :: list()) :: Query.t()
  def where(query, opts \\ []) do
    Enum.reduce(opts, query, fn {key, value}, new_query ->
      {parameter, operator} =
        get_parameter_operator(query.arke, String.split(Atom.to_string(key), "__"))

      filter(new_query, parameter, operator, value)
    end)
  end

  @doc """
  It adds a filter for the given query

  ## Parameters
    - `query` -> refer to `query/1`
    - `filter` -> refer to `Arke.Core.Query.Filter`
  """
  @spec filter(query :: Query.t(), filter :: Query.Filter.t()) :: Query.t()
  def filter(query, filter), do: Query.add_filter(query, filter)

  @doc """
  It adds a filter for the given query
  """
  @spec filter(
          query :: Query.t(),
          parameter :: %Arke{} | String.t() | atom(),
          operator :: operator(),
          value :: any,
          negate :: boolean()
        ) :: Query.t()
  def filter(query, parameter, operator, value, negate \\ false),
    do: handle_filter(query, parameter, operator, value, negate)

  defp handle_filter(query, "group", :eq, value, negate),
    do: handle_filter(query, :group_id, :eq, value, negate)

  defp handle_filter(query, "group_id", :eq, value, negate),
    do: handle_filter(query, :group_id, :eq, value, negate)

  defp handle_filter(query, :group, :eq, value, negate),
    do: handle_filter(query, :group_id, :eq, value, negate)

  defp handle_filter(query, :group_id, :eq, value, negate) do
    %{id: id} = group = get_group(value, query.project)
    arke_list =
      Enum.map(GroupManager.get_arke_list(group), fn a ->
        Atom.to_string(a.id)
      end)

    handle_filter_group(query, group, arke_list, negate)
  end

  defp handle_filter(query, parameter, operator, value, negate),
    do: Query.add_filter(query, get_parameter(query, parameter), operator, value, negate)

  defp handle_filter_group(query, group, arke_list, negate) when is_nil(group), do: query

  defp handle_filter_group(query, group, arke_list, negate),
    do: handle_filter(query, :arke_id, :in, arke_list, negate)

  @doc """
  Define a criteria to order the element returned from a query

  ## Parameter
    - `query` => refer to `query/1`
    - `parameter` => used to order the query
    - `direction` => way of sorting the results (ascending or  descending)
  """
  @spec order(
          query :: Query.t(),
          parameter :: %Arke{} | String.t() | atom(),
          direction :: :asc | :desc
        ) :: Query.t()
  def order(query, parameter, direction),
    do: Query.add_order(query, get_parameter(query, parameter), direction)

  @doc """
  Set the offset of the  query

  ## Parameter
    - `query` -> refer to `query/1`
    - `offset` -> offset of the query
  """
  @spec offset(query :: Query.t(), offset :: integer()) :: Query.t()
  def offset(query, offset), do: Query.set_offset(query, offset)

  @doc """
  Set the limit of the results of a query

  ## Parameter
    - `query` -> refer to `query/1`
    - `limit` -> number of element to return
  """
  @spec limit(query :: Query.t(), limit :: integer()) :: Query.t()
  def limit(query, limit), do: Query.set_limit(query, limit)

  @doc """
  Get both the total count of the elements and the elements returned from the query

  ## Parameter
    - `query` -> refer to `query/1`
    - `offset` -> offset of the query
    - `limit` -> number of element to return
  """
  @spec pagination(query :: Query.t(), offset :: integer(), limit :: integer()) ::
          {count :: integer(), elements :: [] | [%Unit{}]}
  def pagination(query, offset, limit) do
    tmp_query = %{query | orders: []}
    count = count(tmp_query)
    elements = query |> offset(offset) |> limit(limit) |> all
    {count, elements}
  end

  @doc """
  Run the given query and return all the results
  ## Parameter
    - query -> refer to `query/1`
  """
  @spec all(query :: Query.t()) :: [%Unit{}] | []
  def all(query), do: execute_query(query, :all)

  @doc """
    Run the given query and return only the first result
  ## Parameter
    - `query` -> refer to `query/1`

  """
  @spec one(query :: Query.t()) :: %Unit{} | nil
  def one(query), do: execute_query(query, :one)

  @doc """
  Return the given query as a string
  ## Parameter
    - `query` -> refer to `query/1`
  """
  @spec raw(query :: Query.t()) :: String.t()
  def raw(query), do: execute_query(query, :raw)

  @doc """
  Run the given query and return only the number of the records that have been found
  ## Parameter
    - `query` -> refer to `query/1`
  """
  @spec count(query :: Query.t()) :: integer()
  def count(query), do: execute_query(query, :count)

  @doc """
  Return the given query as Ecto pseudo query
  ## Parameter
    - `query` -> refer to `query/1`
  """
  @spec pseudo_query(query :: Query.t()) :: Ecto.Query.t()
  def pseudo_query(query), do: execute_query(query, :pseudo_query)

  ######################################################################################################################
  # PRIVATE FUNCTIONS ##################################################################################################
  ######################################################################################################################

  defp execute_query(query, action) do
    query = handle_arke_filter(query)
    persistence_fn = @persistence[:arke_postgres][:execute_query]
    persistence_fn.(query, action)
  end

  defp handle_arke_filter(%{arke: nil} = query), do: query

  defp handle_arke_filter(%{arke: %{data: %{type: "arke"}, id: id}} = query),
    do: filter(query, :arke_id, :eq, id)

  defp handle_arke_filter(query), do: query

  defp get_parameter_operator(arke, [key, operator]), do: {key, String.to_existing_atom(operator)}
  defp get_parameter_operator(arke, [key]), do: {key, :eq}
  # TODO custom exception
  defp get_parameter_operator(_, _), do: nil

  defp get_parameter(%{arke: nil, project: project} = query, %{id: id} = _parameter),
    do: ParameterManager.get(id, project)

  defp get_parameter(%{arke: nil, project: project} = query, key),
    do: ParameterManager.get(key, project)

  defp get_parameter(%{arke: arke, project: project} = query, key) do
    ArkeManager.get_parameter(arke, project, key)
  end

  defp handle_link_parameters(
         %{arke_id: arke_id, metadata: %{project: project}, data: new_data, id: id} = unit,
         old_data
       ) do
    arke = ArkeManager.get(arke_id, project)

    Enum.filter(ArkeManager.get_parameters(arke), fn p -> p.arke_id == :link end)
    |> Enum.each(fn p ->
      old_value = Map.get(old_data, p.id, nil)
      new_value = Map.get(new_data, p.id, nil)
      handle_link_parameter(unit, p, old_value, new_value)
    end)

    {:ok, unit}
  end

  defp handle_link_parameter(_, nil, _, _), do: nil

  defp handle_link_parameter(unit, %{data: %{multiple: false}} = parameter, old_value, new_value) do
    update_parameter_link(
      unit,
      parameter,
      normalize_value(old_value),
      :delete,
      old_value == new_value
    )

    update_parameter_link(
      unit,
      parameter,
      normalize_value(new_value),
      :add,
      old_value == new_value
    )

    {:ok, unit}
  end

  defp handle_link_parameter(unit, %{data: %{multiple: true}} = parameter, old_value, new_value) do
    # TODO make more efficient with bulk actions

    old_value = old_value || []
    new_value = new_value || []
    nodes_to_delete = Enum.map(old_value -- new_value, &normalize_value(&1))

    nodes_to_add = Enum.map(new_value -- old_value, &normalize_value(&1))

    Enum.each(nodes_to_delete, fn n ->
      update_parameter_link(unit, parameter, n, :delete, false)
    end)

    Enum.each(nodes_to_add, fn n ->
      update_parameter_link(unit, parameter, n, :add, false)
    end)

    {:ok, unit}
  end

  defp update_parameter_link(_, _, _, _, true), do: nil
  defp update_parameter_link(_, _, nil, _, _), do: nil

  defp update_parameter_link(
         %{metadata: %{project: project}} = unit,
         %{
           id: p_id,
           data: %{connection_type: connection_type, direction: "child"}
         } = _parameter,
         id_to_link,
         action,
         false
       ) do
    handle_update_parameter_link(
      project,
      Atom.to_string(unit.id),
      id_to_link,
      connection_type,
      p_id,
      action
    )
  end

  defp update_parameter_link(
         %{metadata: %{project: project}} = unit,
         %{
           id: p_id,
           data: %{connection_type: connection_type, direction: "parent"}
         } = _parameter,
         id_to_link,
         action,
         false
       ) do
    handle_update_parameter_link(
      project,
      id_to_link,
      Atom.to_string(unit.id),
      connection_type,
      p_id,
      action
    )
  end

  defp handle_update_parameter_link(project, from, to, connection_type, p_id, :add) do
    LinkManager.add_node(project, from, to, connection_type, %{parameter_id: Atom.to_string(p_id)})
  end

  defp handle_update_parameter_link(project, from, to, connection_type, p_id, :delete) do
    LinkManager.delete_node(project, from, to, connection_type, %{
      parameter_id: Atom.to_string(p_id)
    })
  end

  # Function to get only the parameter id from `handle_link_parameter`
  defp normalize_value(nil), do: nil

  defp normalize_value(%{id: id} = value) do
    to_string(id)
  end

  defp normalize_value(value), do: to_string(value)
end
