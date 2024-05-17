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

defmodule Arke.Core.Query do
  @moduledoc """
    Struct which defines a Query
  """

  defstruct ~w[project arke persistence filters link orders offset limit]a
  @type t() :: %Arke.Core.Query{}

  defmodule LinkFilter do
    @moduledoc """
      Base struct of a LinkFilter:
      - unit => the starting unit for the query
      - depth =>  how many lookups or lookdowns the recursive query must do
      - direction => the direction the query will use to search,
      - type => the name of the connection we want to look at \n
      It is used to define a common filter struct which will be applied on an arke_link Query
    """
    defstruct ~w[unit depth direction type]a
    @type t() :: %Arke.Core.Query.LinkFilter{}
  end

  defmodule Filter do
    @moduledoc """
      Base struct of a Filter:
      - logic => :and | :or => the logic of the filter
      - negate => boolean => used to figure out whether the condition is to be denied
      - base_filters (refer to `Arke.Core.Query.BaseFilter`).\n
      It is used to define a Filter which will be applied on a Query
    """
    defstruct ~w[logic negate base_filters]a
    @type t() :: %Arke.Core.Query.Filter{}
  end

  defmodule BaseFilter do
    @moduledoc """
      Base struct of a BaseFilter:
      - parameter => %Arke.Core.Parameter.`ParameterType` => refer to `Arke.Core.Parameter`
      - operator => refer to [operators](#module-operators)
      - value => any => the value that the query will search for
      - negate => boolean => used to figure out whether the condition is to be denied \n
      It is used to keep the same logic structure across all the Filter
    """

    defstruct ~w[parameter operator value negate]a
    @type t() :: %Arke.Core.Query.BaseFilter{}

    @doc """
    Create a new BaseParameter

    ## Parameters
      - parameter => Parameter on which the base filter will be applied
      - operator => refer to [operators](#module-operators)
      - value => the value that the query will search for
      - negate =>  used to figure out whether the condition is to be denied \n
    """
    @spec new(
            parameter :: %Arke.Core.Unit{},
            operator :: atom(),
            value :: any,
            negate :: boolean
          ) :: Arke.Core.Query.BaseFilter.t()
    def new(parameter, operator, value, negate) do
      %__MODULE__{
        parameter: parameter,
        operator: operator,
        value: cast_value(parameter, value),
        negate: negate
      }
    end

    defp cast_value(%Arke.Core.Unit{arke_id: arke_id} = parameter, value) do
      case arke_id do
        :datetime ->
          Arke.Utils.DatetimeHandler.parse_datetime(value)
          |> case do
            {:ok, value} -> value
            _ -> raise ArgumentError, message: "Invalid datetime format"
          end

        _ ->
          value
      end
    end

    defp cast_value(parameter, value), do: value
  end

  defmodule Order do
    @moduledoc """
      Base struct Order:
      - parameter => Parameter on which the order will be applied
      - direction => the direction the query will use to search \n
      It is used to define the return order of a Query
    """
    defstruct ~w[parameter direction]a
    @type t() :: %Arke.Core.Query.Order{}
  end

  @doc """
  Create a new Query

  ## Parameters
    - arke => %Arke.Core.`{arke_struct}`{} => the `arke_struct` of the unit which we want to filter on. See `Arke.Struct`
    - project => :atom =>  identify the `Arke.Core.Project`
  """
  @spec new(arke :: %Arke.Core.Arke{}, project :: atom()) :: Arke.Core.Query.t()
  def new(arke, project),
    do: %__MODULE__{
      project: project,
      arke: arke,
      persistence: nil,
      filters: [],
      orders: [],
      offset: nil,
      limit: nil
    }

  @doc """
  Add a new link filter in order to make a recursive query in the topology table.
  ## Parameters
    - query => refer to `new/1`
    - unit => the starting unit for the query
    - depth =>  how many lookups or lookdowns the recursive query must do
    - direction => the direction the query will use to search
    - type => the name of the link we want to look at
  """
  @spec add_link_filter(
          query :: Arke.Core.Query.t(),
          unit :: %Arke.Core.Unit{},
          depth :: integer(),
          direction :: :child | :parent,
          connection_type :: String.t()
        ) :: Arke.Core.Query.t()
  def add_link_filter(query, unit, depth, direction, type) do
    %{query | link: %LinkFilter{unit: unit, depth: depth, direction: direction, type: type}}
  end

  @doc """
  Add a filter to a query

  ## Parameters
    - query => refer to `new/1`
    - filter => refer to `Arke.Core.Query.BaseFilter`
  """
  def add_filter(query, filter) do
    %{query | filters: [filter | query.filters]}
  end

  @doc """
  Add a filter to a query

  ## Parameters
    - query => refer to `new/1`
    - parameter
    - operator
    - value
    - negate
  """
  def add_filter(query, parameter, operator, value, negate) do
    %{query | filters: [new_filter(parameter, operator, value, negate) | query.filters]}
  end

  @doc """
  Add a filter to a query

  ## Parameters
    - query => refer to `new/1`
    - logic => the logic of the filter
    - negate => used to figure out whether the condition is to be denied
    - base_filters  => One or a list of `Arke.Core.Query.BaseFilter`
  """
  @spec add_filter(
          query :: Arke.Core.Query.t(),
          logic :: :and | :or,
          negate :: boolean,
          base_filters :: Arke.Core.Query.BaseFilter.t() | [Arke.Core.Query.BaseFilter.t()]
        ) :: Arke.Core.Query.t()
  def add_filter(query, logic, negate, base_filters) do
    %{query | filters: [new_filter(logic, negate, base_filters) | query.filters]}
  end

  @doc """
  Create a new filter
  ## Parameters
    - parameter => Parameter to filter
    - operator => refer to [operators](#module-operators)
    - value => the value that the query will search for
    - negate => used to figure out whether the condition is to be denied
  """
  @spec new_filter(
          parameter :: %Arke.Core.Unit{},
          operator :: Arke.Core.QueryManager.operator(),
          value :: any,
          negate :: boolean()
        ):: Arke.Core.Query.Filter.t()
  def new_filter(parameter, operator, value, negate) do
    %Filter{
      logic: :and,
      negate: false,
      base_filters: [new_base_filter(parameter, operator, value, negate)]
    }
  end

  @doc """
  Create a new filter
  ## Parameters
    - logic => the logic of the filter
    - negate => used to figure out whether the condition is to be denied
    - base_filters => refer to `Arke.Core.Query.BaseFilter`
  """
  @spec new_filter(
          logic :: :and | :or,
          negate :: boolean(),
          base_filters :: Arke.Core.Query.BaseFilter.t() | [Arke.Core.Query.BaseFilter.t()]
        ):: Arke.Core.Query.Filter.t()
  def new_filter(logic, negate, base_filters) do
    %Filter{base_filters: parse_base_filters(base_filters), logic: logic, negate: negate}
  end

  @doc """
  Create a new base filter

  ## Parameters
    - parameter => Parameter to filter
    - operator => refer to [operators](#module-operators)
    - value =>  the value that the query will search for
    - negate => used to figure out whether the condition is to be denied

  """
  @spec new_base_filter(
  parameter :: %Arke.Core.Unit{},
  operator :: Arke.Core.QueryManager.operator(),
  value :: any,
  negate :: boolean()
  ) :: Arke.Core.Query.BaseFilter.t()
  def new_base_filter(parameter, operator, value, negate) do
    BaseFilter.new(parameter, operator, value, negate)
  end

  defp parse_base_filters(base_filters) when is_list(base_filters), do: base_filters
  defp parse_base_filters(base_filters), do: [base_filters]

  @doc """
  Get the query result ordered by specific criteria

  ## Parameters
    - query => refer to `new/1`
    - parameter => parameter used to order the query results
    - direction => the direction the query will use to search
  """
  @spec add_order(
          query :: Arke.Core.Query.t(),
          parameter :: %Arke.Core.Unit{},
          direction :: :asc | :desc
        ):: Arke.Core.Query.t()
  def add_order(query, parameter, direction) do
    %{
      query
      | orders: [%Order{parameter: parameter, direction: direction} | query.orders]
    }
  end

  @doc """
  Define the offset of the query

  ## Parameters
    - query => refer to `new/1`
    - offset => define the offset of the query
  """
  @spec set_offset(query :: Arke.Core.Query.t(), offset :: nil | number() | String.t()):: Arke.Core.Query.t()
  def set_offset(query, nil), do: query

  def set_offset(query, offset) when is_binary(offset),
    do: %{query | offset: String.to_integer(offset)}

  def set_offset(query, offset) when is_integer(offset), do: %{query | offset: offset}
  # TODO Custom exception offset must be integer
  def set_offset(query, offset), do: nil

  @doc """
  Define the limit of the query

  ## Parameters
    - query => refer to `new/1`
    - limit => integer => set the results limit of the query
  """
  @spec set_limit(query :: Arke.Core.Query.t(), offset :: nil | number() | String.t()):: Arke.Core.Query.t()
  def set_limit(query, nil), do: query

  def set_limit(query, offset) when is_binary(offset),
    do: %{query | limit: String.to_integer(offset)}

  def set_limit(query, limit) when is_integer(limit), do: %{query | limit: limit}
  # TODO Custom exception limit must be integer
  def set_limit(query, limit), do: nil
end
