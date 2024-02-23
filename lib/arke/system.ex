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

defmodule Arke.System do
  defmacro __using__(_) do
    quote do
      #      @after_compile __MODULE__
      Module.register_attribute(__MODULE__, :arke, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :groups, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :parameters, accumulate: true, persist: false)

      Module.put_attribute(__MODULE__, :system_arke, true)

      import unquote(__MODULE__),
        only: [arke: 1, arke: 2, parameter: 3, parameter: 2, group: 1, group: 2]

      #      @before_compile unquote(__MODULE__)

      def arke_from_attr(),
        do: Keyword.get(__MODULE__.__info__(:attributes), :arke, []) |> List.first()

      def groups_from_attr(), do: Keyword.get(__MODULE__.__info__(:attributes), :groups, [])

      def base_parameters() do
        unit = arke_from_attr()
        unit.data.parameters
      end

      def on_load(data, _persistence_fn), do: {:ok, data}
      def before_load(data, _persistence_fn), do: {:ok, data}
      def on_validate(arke, unit), do: {:ok, unit}
      def before_validate(arke, unit), do: {:ok, unit}
      def on_create(arke, unit), do: {:ok, unit}
      def before_create(arke, unit), do: {:ok, unit}
      def on_struct_encode(_, _, data, opts), do: {:ok, data}
      def before_struct_encode(_, unit), do: {:ok, unit}
      def on_update(arke, old_unit, unit), do: {:ok, unit}
      def before_update(arke, unit), do: {:ok, unit}
      def on_delete(arke, unit), do: {:ok, unit}
      def before_delete(arke, unit), do: {:ok, unit}

      def after_get_struct(arke, unit, struct), do: struct
      def after_get_struct(arke, struct), do: struct

      defoverridable on_load: 2,
                     before_load: 2,
                     on_validate: 2,
                     before_validate: 2,
                     on_create: 2,
                     before_create: 2,
                     before_struct_encode: 2,
                     on_struct_encode: 4,
                     on_update: 3,
                     before_update: 2,
                     on_delete: 2,
                     before_delete: 2,
                     after_get_struct: 2,
                     after_get_struct: 3
    end
  end

  #  defmacro __before_compile__(env) do
  #  end
  #
  #  def compile(translations) do
  #
  #  end

  ######################################################################################################################
  # ARKE MACRO #########################################################################################################
  ######################################################################################################################

  @doc """
  Macro to create an arke struct with the given parameters.
  Usable only via `code` and not `iex`.


  ## Example
      arke  do
        parameter :custom_parameter, :string, required: true, unique: true
        parameter :custom_parameter2, :string, required: true, values: ["value1", "value2"]
        parameter :custom_parameter3, :integer, required: true, values: [%{label: "option 1", value: 1},%{label: "option 2", value: 2}]
        parameter :custom_parameter4, :dict, required: true, default: %{"default_dict_key": "default_dict_value"}
      end

  ## Return
      %Arke.Core.'{arke_struct}'{}

  """
  @spec arke(args :: list(), Macro.t()) :: %{}
  defmacro arke(opts \\ [], do: block) do
    type = Keyword.get(opts, :type, "arke")
    active = Keyword.get(opts, :active, true)
    metadata = Keyword.get(opts, :metadata, %{})

    base_parameters = get_base_arke_parameters(type)

    quote do
      type = unquote(type)
      active = unquote(active)
      opts = unquote(opts)
      metadata = unquote(Macro.escape(metadata))
      caller = unquote(__CALLER__.module)

      # todo: remove string to atom
      id =
        Keyword.get(
          opts,
          :id,
          caller
          |> to_string
          |> String.split(".")
          |> List.last()
          |> Macro.underscore()
          |> String.to_atom()
        )

      label =
        Keyword.get(
          opts,
          :label,
          id |> to_string |> String.replace("_", " ") |> String.capitalize()
        )

      unquote(base_parameters)
      unquote(block)

      @arke %{
        id: id,
        data: %{label: label, active: active, type: type, parameters: @parameters},
        metadata: metadata,
      }

    end
  end

  defp get_base_arke_parameters("arke") do
    quote do
      parameter(:id, :string, required: true, persistence: "table_column")
      parameter(:arke_id, :string, required: false, persistence: "table_column")
      parameter(:metadata, :dict, required: false, persistence: "table_column")
      parameter(:inserted_at, :datetime, required: false, persistence: "table_column")
      parameter(:updated_at, :datetime, required: false, persistence: "table_column")
    end
  end

  defp get_base_arke_parameters(_type), do: nil

  #  @spec __arke_info__(caller :: caller(), options :: list()) :: [id: atom() | String.t(), label: String.t(), active: boolean(), metadata: map(), type: atom()]
  #  defp __arke_info__(caller, options) do
  #
  #    id = Keyword.get(options, :id, caller |> to_string |> String.split(".") |> List.last |> Macro.underscore |> String.to_atom)
  #    label = Keyword.get(options, :label, id |> Atom.to_string |> String.replace("_", " ") |> String.capitalize)
  #    [
  #      id: id,
  #      label: label,
  #      active: Keyword.get(options, :active, true),
  #      metadata: Keyword.get(options, :metadata, %{}),
  #      type: Keyword.get(options, :type, :arke)
  #    ]
  #  end

  ######################################################################################################################
  # END ARKE MACRO #####################################################################################################
  ######################################################################################################################

  ######################################################################################################################
  # PARAMETER MACRO ####################################################################################################
  ######################################################################################################################

  @doc """
  Macro used to define parameter in an arke.
  See example above `arke/2`

  """
  @spec parameter(id :: atom(), type :: atom(), opts :: list()) :: Macro.t()
  defmacro parameter(id, type, opts \\ []) do
    # parameter_dict = Arke.System.BaseParameter.parameter_options(opts, id, type)
    quote bind_quoted: [id: id, type: type, opts: opts] do
      opts = Arke.System.BaseParameter.check_enum(type, opts)
      @parameters %{id: id, arke: type, metadata: opts}
    end
  end

  ######################################################################################################################
  # END PARAMETER MACRO ################################################################################################
  ######################################################################################################################

  ######################################################################################################################
  # GROUP MACRO ####################################################################################################
  ######################################################################################################################

  @doc """
  Macro used to define parameter in an arke.
  See example above `arke/2`

  """
  @spec group(id :: atom(), opts :: list()) :: Macro.t()
  defmacro group(id, opts \\ []) do
    quote bind_quoted: [id: id, opts: opts] do
      @groups %{id: id, metadata: opts}
    end
  end

  ######################################################################################################################
  # END GROUP MACRO ################################################################################################
  ######################################################################################################################
end

defmodule Arke.System.Arke do
  use Arke.System
end

defmodule Arke.System.BaseArke do
  defstruct [:id, :label, :active, :type, :parameters, :metadata]
end

defmodule Arke.System.BaseParameter do
  defstruct [:id, :label, :active, :metadata, :type, :parameters]

  @doc """
  Used in the parameter macro to create the map for every parameter which have the `values` option.
  It check if the given value are the same type as the parameter type and then creates a  list of map as follows:

       [%{label "given label", value: given_value}, %{label "given label two ", value: given_value_two}]

  Keep in mind that if the values are declared as list instead of map the label will be generated from the value itself.
       ... omitted code

            parameter :custom_parameter2, :integer, required: true, values: [1, 2, 3]

       ... omitted code
    The code above will results in an `{arke_struct}` with the values as follows

        ... omitted code

            values: [%{label "1", value: 1}, %{label "2", value: 2}, %{label "3", value: 3}]

        ... omitted code

  """
  @spec parameter_options(opts :: list(), id :: atom(), type :: atom()) :: %{
          type: atom(),
          opts: list()
        }
  def parameter_options(opts, id, type) do
    opts =
      opts
      |> parameter_option_common(id)
      |> parameter_by_type(type)

    %{type: type, opts: opts}
  end

  def check_enum(type, opts) when is_binary(type), do: check_enum(String.to_atom(type),opts)
  def check_enum(type, opts) do
    enum_parameters = [:string, :integer, :float]
    case type in enum_parameters do
      true -> __enum_parameter__(opts, type)
      false -> opts
    end

  end

  defp parameter_option_common(opts, id) do
    opts
    |> Keyword.put(:id, id)
    |> Keyword.put(
      :label,
      Keyword.get(
        opts,
        :label,
        id |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
      )
    )
    |> parameter_option(:required, false)
    |> parameter_option(:nullable, true)
    |> parameter_option(:default, nil)
    |> parameter_option(:persistence, "arke_parameter")
  end

  defp parameter_by_type(opts, :string) do
    opts
    |> parameter_option(:type, :string)
    |> parameter_option(:min_length, nil)
    |> parameter_option(:max_length, nil)
    |> parameter_option(:strip, nil)
    |> __enum_parameter__(:string)
  end

  defp parameter_by_type(opts, :integer) do
    opts
    |> parameter_option(:type, :integer)
    |> __number_parameter__()
    |> __enum_parameter__(:integer)
  end

  defp parameter_by_type(opts, :float) do
    opts
    |> parameter_option(:type, :float)
    |> __number_parameter__()
    |> __enum_parameter__(:float)
  end

  defp parameter_by_type(opts, type), do: opts |> parameter_option(:type, type)

  defp __number_parameter__(opts) do
    opts
    |> parameter_option(:min, nil)
    |> parameter_option(:max, nil)
  end

  defp parameter_option(opts, key, default) do
    Keyword.put_new(opts, key, default)
  end

  defp __enum_parameter__(opts, type) when is_map(opts), do: __enum_parameter__(Map.to_list(opts),type)
  defp __enum_parameter__(opts, type) do
    case Keyword.has_key?(opts, :values) do
      true ->   __validate_values__(opts, opts[:values], type)
      false ->
        opts
    end
  end

  defp __validate_values__(opts, nil, _), do: opts

  defp __validate_values__(opts, %{"value" => value, "datetime" => _} = _values, type)
       when not is_nil(value),
       do: __validate_values__(opts, value, type)


  defp __validate_values__(opts, [h | _t] = values, type) when is_map(h) do

    condition =
      cond do
        type == :string ->
          fn l, v -> (is_binary(l) and is_binary(v)) or (is_atom(l) and is_atom(v)) end

        type == :integer ->
          fn l, v -> is_binary(l) and is_integer(v) end

        type == :float ->
          fn l, v -> is_binary(l) and is_number(v) end
      end
    case Enum.all?(values, fn map ->
           Enum.map([:label, :value], fn key -> Map.has_key?(map, key) end)
         end) do
      true ->
       __create_map_values__(__check_map__(values), opts, type, condition)

      # FARE RAISE ECCEZIONE DA GESTIRE. CHIAVI DEVONO ESSERE TUTTE UGUALI
      _ ->
        Keyword.update(opts, :values, nil, fn _current_value -> nil end)
    end
  end

  defp __validate_values__(opts, values, type) do
    condition =
      cond do
        type == :string -> fn v -> is_binary(v) or is_atom(v) end
        type == :integer -> fn v -> is_integer(v) end
        type == :float -> fn v -> is_number(v) end
      end

    __values_from_list__(values, opts, condition)
  end


  # CONVERT ALL STRINGS KEY TO ATOMS (string are received from API)
  defp __check_map__([%{"label" => _l, "value" => _v} | _h] = values) do
    Enum.map(
      values,
      &Enum.into(&1, %{}, fn {key, val} -> {String.to_existing_atom(key), val} end)
    )
  end

  defp __check_map__(values), do: values

  defp __create_map_values__(values, opts, type, condition) do
    # FARE RAISE ECCEZIONE DA GESTIRE. CHIAVI DEVONO ESSERE TUTTE UGUALI
    with true <- Enum.all?(values, fn %{label: l, value: v} -> condition.(l, v) end) do
      new_values =
        Enum.map(values, fn k ->
          %{label: String.capitalize(to_string(k.label)), value: __get_map_value__(k.value, type)}
        end)

      __create_index__(opts, new_values)
    else
      _ -> Keyword.update(opts, :values, nil, fn _current_value -> nil end)
    end
  end

  defp __get_map_value__(value, :string), do: to_string(value)
  defp __get_map_value__(value, _), do: value

  defp __values_from_list__(values, opts, condition) do
    # FARE RAISE ECCEZIONE DA GESTIRE. CHIAVI DEVONO ESSERE TUTTE UGUALI
    with true <- Enum.all?(values, &condition.(&1)) do
      new_values =
        Enum.map(values, fn k -> %{label: String.capitalize(to_string(k)), value: k} end)

      __create_index__(opts, new_values)
    else
      _ -> Keyword.update(opts, :values, nil, fn _current_value -> nil end)
    end
  end

  defp __create_index__(opts, new_values),
    do: Keyword.delete(opts, :values) |> Keyword.put_new(:values, new_values)
end
