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

defmodule Arke.Core.Parameter do
  @moduledoc """
  Module to manage the defaults parameter

  In order to create a new one simply use the .new(opts)

  ## Types
    - `string`
    - `integer`
    - `float`
    - `boolean`
    - `dict`
    - `date`
    - `time`
    - `datetime`

  ## Values
  There are two possible ways to declare the values for a parameter:
    - list => by giving a list of values \n
          values: ["value 1", "value 2", ...."value n"]
    - list of map => by giving a list of map. Each map **must** contain `label` and `value`. \n
          values: [%{label:"value 1", value: 1},... %{label: "value 999", value: 999}]

    The result will always be a list of map containing `label` and `value`. Keep in mind that if the values are provided using a list the `label` will be autogenerated.
    Remember also that all the values provided must be the same type as the [ParameterType](#module-types) and only `string`, `integer` and `float` support the `values` declaration

  ## Get list of attributes definable in opts during creation:
      iex> Arke.Core.Parameter.'ParameterType'.get_parameters()
  """
  alias Arke.Core.Parameter

  @type parameter_struct() ::
          Parameter.Boolean.t()
          | Parameter.String.t()
          | Parameter.Dict.t()
          | Parameter.Integer.t()
          | Parameter.Float.t()

  @doc """
       Macro defining a shared struct of parameter used across Arkes
       """ && false

  defmacro base_parameters() do
    quote do
      group(:parameter)

      parameter(:label, :string, required: true)
      parameter(:format, :string, default_string: "attribute")
      parameter(:is_primary, :boolean, default_boolean: false)
      parameter(:nullable, :boolean, default_boolean: true)
      parameter(:required, :boolean, default_boolean: false)
      parameter(:persistence, :string, default_string: "arke_parameter")
      parameter(:only_run_time, :boolean, default_boolean: false)
      parameter(:helper_text, :string, required: false)
    end
  end

  #  @doc """
  #  Create new parameter by passing the type and the options to assign
  #
  #  ## Parameters
  #    - opts => %{type: `ParameterType`, opts: [keyword: value] | %{map}} => opts like the `id` we want to give to the parameter we are creating.
  #      {[type](#module-types): `ParameterType`} is required unless you want to create a generic parameter with no type
  #
  #
  #  ## Examples
  #      iex> Arke.Core.Parameter.new(%{type: :string, opts: [id: "test"]})
  #
  #  ## Return
  #      %Arke.Core.Parameter.'ParameterType'{}
  #
  #  """
  #  @spec new(arg1 :: %{type: atom(), opts: list(parameter_struct())}) :: parameter_struct()
  #  def new(%{type: :string, opts: opts} = _), do: Parameter.String.new([{:type, :string} | opts])
  #  def new(%{type: :atom, opts: opts} = _), do: Parameter.String.new([{:type, :string} | opts])
  #  def new(%{type: :integer, opts: opts} = _), do: Parameter.Integer.new([{:type, :integer} | opts])
  #  def new(%{type: :float, opts: opts} = _), do: Parameter.Float.new([{:type, :float} | opts])
  #  def new(%{type: :boolean, opts: opts} = _), do: Parameter.Boolean.new([{:type, :boolean} | opts])
  #  def new(%{type: :date, opts: opts} = _), do: Parameter.Date.new([{:type, :date} | opts])
  #  def new(%{type: :time, opts: opts} = _), do: Parameter.Time.new([{:type, :time} | opts])
  #  def new(%{type: :datetime, opts: opts} = _), do: Parameter.DateTime.new([{:type, :datetime} | opts])
  #  def new(%{type: :dict, opts: opts} = _), do: Parameter.Dict.new([{:type, :dict} | opts])
  #  def new(%{opts: opts} = _), do: Enum.into(opts, %{helper_text: ""})
end

defmodule Arke.Core.Parameter.String do
  @moduledoc """
  Module that define the struct of a String by extending the Arke.Core.Parameter.base_parameters()
      {arke_struct} = Parameter.String

  ## Element added
    - `min_length` => :atom => define the min_length the string could have. It will check during creation
    - `max_length` => :atom => define the max_length the string could have. It will check during creation
    - `values` => [list] || [%{label: string, value: any}, ...] => use this to create a parameter with only certain values assignable. (Values must be the same type as the parameter we want to create)
    - `multiple` => boolean => relevant only if values are set. It makes possible to assign more than a values defined in values
    - `unique` => boolean => check if there is an existing record in the database  with the same value before creating one
    - `default` => String => default value

  ## Example
      iex> params = [id: :string_test, min_length: 1, values: ["value1", "value2"], multiple: true]
      ...> Arke.Core.Parameter.new(%{type: :string, opts: params})

  ## Return
      %Arke.Core.Parameter.String{}
  """
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:min_length, :integer, required: false)
    parameter(:max_length, :integer, required: false)
    parameter(:strip, :boolean, default_boolean: false)
    parameter(:values, :list, required: false)
    parameter(:multiple, :boolean, default_boolean: false)
    parameter(:unique, :boolean, required: false)
    parameter(:default_string, :string, default_string: nil)
  end

  def before_load(data, _persistence_fn) do
    args = Arke.System.BaseParameter.check_enum(:string, Map.to_list(data))
    {:ok, Enum.into(args, %{})}
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.Integer do
  @moduledoc """
  Module that define the struct of a Integer by extending the Arke.Core.Parameter.base_parameters()
      {arke_struct} = Parameter.Integer

  ## Element added
    - `min` => :atom => define the mix value the parammeter could have
    - `max` => :atom => define the max the parammeter could have
    - `values` => [list] || [%{label: string, value: any}, ...] => use this to create a parameter with only certain values assignable. (Values must be the same type as the parameter we want to create)
    - `multiple` => boolean => relevant only if values are set. It makes possible to assign more than a values defined in values
    - `default` => Integer => default value

    ## Example
        iex> params = [id: :integer_test, min: 3, max: 7.5, values: [%{label: "option 1", value: 1}, %{label: "option 2", value: 2}]]
        ...> Arke.Core.Parameter.new(%{type: :integer, opts: params})

    ## Return
        %Arke.Core.Parameter.Float{}
  """
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:min, :integer, required: false)
    parameter(:max, :integer, required: false)
    parameter(:values, :list, required: false)
    parameter(:multiple, :boolean, default_boolean: false)
    parameter(:default_integer, :integer, default_integer: nil)
  end

  def before_load(data, _persistence_fn) do
    args = Arke.System.BaseParameter.check_enum(:integer, Map.to_list(data))
    {:ok, Enum.into(args, %{})}
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.Float do
  @moduledoc """
  Module that define the struct of a Float by extending the Arke.Core.Parameter.base_parameters()
      {arke_struct} = Parameter.Float

  ## Element added
    - `min` => :atom => define the mix value the parammeter could have
    - `max` => :atom => define the max the parammeter could have
    - `values` => [list] || [%{label: string, value: any}, ...] => use this to create a parameter with only certain values assignable. (Values must be the same type as the parameter we want to create)
    - `multiple` => boolean => relevant only if values are set. It makes possible to assign more than a values defined in values
    - `default` => Float => default value

    ## Example
        iex> params = [id: :float_test, min: 3, max: 7.5]
        ...> Arke.Core.Parameter.new(%{type: :float, opts: params})

    ## Return
        %Arke.Core.Parameter.Float{}
  """
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:min, :float, required: false)
    parameter(:max, :float, required: false)
    parameter(:values, :list, required: false)
    parameter(:multiple, :boolean, default_boolean: false)
    parameter(:default_float, :float, default_float: nil)
  end

  def before_load(data, _persistence_fn) do
    args = Arke.System.BaseParameter.check_enum(:float, Map.to_list(data))
    {:ok, Enum.into(args, %{})}
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.Boolean do
  @moduledoc """
  Module that define the struct of a Boolean by extending the Arke.Core.Parameter.base_parameters()
      {arke_struct} = Parameter.Boolean

  ## Element added
    - `default` => Boolean => default value

  ## Example
      iex> params = [id: :boolean_test, default: false]
      ...> Arke.Core.Parameter.Boolean(%{type: :boolean, opts: params})

  ## Return
      %Arke.Core.Parameter.Boolean{}
  """
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:default_boolean, :boolean, default_boolean: false)
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.Dict do
  @moduledoc """
  Module that define the struct of a Dict by extending the Arke.Core.Parameter.base_parameters()
      {arke_struct} = Parameter.Dict

  ## Element added
    - `default` => Dict => default value

  ## Example
      iex> params = [id: :dict_test, default: %{default_key: default_value}]
      ...> Arke.Core.Parameter.Dict(%{type: :dict, opts: params})

  ## Return
      %Arke.Core.Parameter.Dict{}
  """
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:default_dict, :dict, default_dict: nil)
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.List do
  @moduledoc """
  Module that define the struct of a Dict by extending the Arke.Core.Parameter.base_parameters()
      {arke_struct} = Parameter.Dict

  ## Element added
    - `default` => Dict => default value

  ## Example
      iex> params = [id: :dict_test, default: %{default_key: default_value}]
      ...> Arke.Core.Parameter.Dict(%{type: :dict, opts: params})

  ## Return
      %Arke.Core.Parameter.Dict{}
  """
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:default_list, :list, default_list: nil)
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.Date do
  @moduledoc """
  Module that define the struct of a Date by extending the Arke.Core.Parameter.base_parameters().

  ## Accepted values
  Date accepts the following format as values:
    - string => "YYYY-MM-DD" (separator must be - hyphen)
    - sigil => ~D[YYYY-MM-DD] (separator must be - hyphen)
    - struct => %Date{}

      {arke_struct} = Parameter.Date

  ## Element added
    - `default` => [values](#module-accepted-values) => default value

    ## Example
        iex> params = [id: :date_test, default: "1999-09-03"]
        ...> Arke.Core.Parameter.new(%{type: :date, opts: params})

    ## Return
        %Arke.Core.Parameter.Date{}
  """

  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:default_date, :date, default_date: nil)
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.Time do
  @moduledoc """
  Module that define the struct of a Time by extending the Arke.Core.Parameter.base_parameters().

  ## Accepted values
  Date accepts the following format as values:
    - string => "HH:MM:SS" (separator must be - hyphen)
    - sigil => ~T[HH:MM:SS] (separator must be - hyphen)
    - struct => %Time{}

      {arke_struct} = Parameter.Date

  ## Element added
    - `default` => [values](#module-accepted-values) => default value

    ## Example
        iex> params = [id: :time_test, default: "23:14:15"]
        ...> Arke.Core.Parameter.new(%{type: :time, opts: params})

    ## Return
        %Arke.Core.Parameter.Time{}
  """
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:default_time, :time, default_time: nil)
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.DateTime do
  @moduledoc """
  Module that define the struct of a DateTime by extending the Arke.Core.Parameter.base_parameters().

  ## Accepted values
  Date accepts the following format as values:
    - string => "YYYY-MM-DDTHH:MM:SSZ" | "YYYY-MM-DD HH:MM:SSZ" | "YYYY-MM-DD HH:MM:SS" (separator must be - hyphen for Date and colon :  for Time)
    - sigil => ~U[YYYY-MM-DDTHH:MM:SSZ] | ~U[YYYY-MM-DD HH:MM:SSZ] | ~N[YYYY-MM-DDTHH:MM:SSZ] | ~N[YYYY-MM-DD HH:MM:SSZ] |  ~N[YYYY-MM-DD HH:MM:SS] (separator must be - hyphen for Date and colon :  for Time)
    - struct => %DateTime{} | %NaiveDateTime{}

    The T separator is optional. If no offset is provided (Z will be added at the end)

      {arke_struct} = Parameter.Date

  ## Element added
    - `default` => [values](#module-accepted-values) => default value

    ## Example
        iex> params = [id: :time_test, default: "1999-12-12 09:08:07"]
        ...> Arke.Core.Parameter.new(%{type: :datetime, opts: params})

    ## Return
        %Arke.Core.Parameter.DateTime{}
  """

  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke id: :datetime do
    Parameter.base_parameters()
    parameter(:default_datetime, :datetime, default_datetime: nil)
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.Link do
  @moduledoc """
  Module that define the struct of a Link by extending the Arke.Core.Parameter.base_parameters()
      {arke_struct} = Parameter.Link

  ## Element added
    - `link` => Link => link handler

  ## Example
      iex> params = [id: :dict_test, default: %{default_key: default_value}]
      ...> Arke.Core.Parameter.Dict(%{type: :dict, opts: params})

  ## Return
      %Arke.Core.Parameter.Dict{}
  """
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:multiple, :boolean, default_boolean: false)

    parameter(:arke_or_group_id, :link,
      multiple: false,
      required: true,
      helper_text: "Arke or Group id"
    )

    parameter(:depth, :integer, default_integer: 0)
    parameter(:connection_type, :string, default_string: "link")
    parameter(:default_link, :link, default_link: nil)
    parameter(:filter_keys, :string, default_string: ["id", "arke_id"])
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.Dynamic do
  @moduledoc """
  Module that define the struct of a Dynamic by extending the Arke.Core.Parameter.base_parameters()
      {arke_struct} = Parameter.Dynamic

  ## Return
      %Arke.Core.Parameter.Dynamic{}
  """
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:default_dynamic, :dynamic, default_dynamic: nil)
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end

defmodule Arke.Core.Parameter.Binary do
  @moduledoc """
  Module that define the struct of a Binary by extending the Arke.Core.Parameter.base_parameters()
      {arke_struct} = Parameter.Binary

  ## Return
      %Arke.Core.Parameter.Binary{}
  """
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  require Parameter
  use Arke.System

  arke do
    Parameter.base_parameters()
    parameter(:default_binary, :binary, default_binary: nil)
  end

  def on_create(_, %{metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.create(unit, project)
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, %{id: id, metadata: %{project: project}} = unit) do
    Arke.Boundary.ParamsManager.remove(id, project)
    ParameterManager.remove(unit)
    {:ok, unit}
  end
end
