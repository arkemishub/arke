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

defmodule Arke.System.Group do
  defmacro __using__(_) do
    quote do
      #      @after_compile __MODULE__
      Module.register_attribute(__MODULE__, :group, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :parameters, accumulate: true, persist: false)
      Module.register_attribute(__MODULE__, :system_group, accumulate: false, persist: true)
      Module.put_attribute(__MODULE__, :system_group, true)

      import unquote(__MODULE__),
        only: [group: 1, group: 2, parameter: 3, parameter: 2]

      #      @before_compile unquote(__MODULE__)

      def group_from_attr(),
        do: Keyword.get(__MODULE__.__info__(:attributes), :group, []) |> List.first()

      def is_group?(),
        do: Keyword.get(__MODULE__.__info__(:attributes), :system_group, []) |> List.first()

      def on_unit_load(arke, data, _persistence_fn), do: {:ok, data}
      def before_unit_load(_arke, data, _persistence_fn), do: {:ok, data}
      def on_unit_validate(_arke, unit), do: {:ok, unit}
      def before_unit_validate(_arke, unit), do: {:ok, unit}
      def on_unit_create(_arke, unit), do: {:ok, unit}
      def before_unit_create(_arke, unit), do: {:ok, unit}
      def on_unit_struct_encode(unit, _), do: {:ok, unit}
      def on_unit_update(_arke, unit), do: {:ok, unit}
      def before_unit_update(_arke, unit), do: {:ok, unit}
      def on_unit_delete(_arke, unit), do: {:ok, unit}
      def before_unit_delete(_arke, unit), do: {:ok, unit}

      defp before_unit_bulk_create(arke, valid, errors), do: {:ok, valid, errors}
      defp on_unit_bulk_create(arke, valid, errors), do: {:ok, valid, errors}
      defp before_unit_bulk_update(arke, valid, errors), do: {:ok, valid, errors}
      defp on_unit_bulk_update(arke, valid, errors), do: {:ok, valid, errors}
      defp before_unit_bulk_delete(arke, valid, errors), do: {:ok, valid, errors}
      defp on_unit_bulk_delete(arke, valid, errors), do: {:ok, valid, errors}

      defoverridable on_unit_load: 3,
                     before_unit_load: 3,
                     on_unit_validate: 2,
                     before_unit_validate: 2,
                     on_unit_create: 2,
                     before_unit_create: 2,
                     on_unit_struct_encode: 2,
                     on_unit_update: 2,
                     before_unit_update: 2,
                     on_unit_delete: 2,
                     before_unit_delete: 2,
                     before_unit_bulk_create: 3,
                     on_unit_bulk_create: 3,
                     before_unit_bulk_update: 3,
                     on_unit_bulk_update: 3,
                     before_unit_bulk_delete: 3,
                     on_unit_bulk_delete: 3
    end
  end

  #  defmacro __before_compile__(env) do
  #  end
  #
  #  def compile(translations) do
  #
  #  end

  ######################################################################################################################
  # Group MACRO #########################################################################################################
  ######################################################################################################################

  @doc """
  Macro to create an arke struct with the given parameters.
  Usable only via `code` and not `iex`.


  ## Example
      group do
        parameter :custom_parameter
        parameter :custom_parameter2
        parameter :custom_parameter3
        parameter :custom_parameter4
      end

  ## Return
      %Arke.Core.Unit{}

  """
  @spec group(args :: list(), Macro.t()) :: %{}
  defmacro group(opts \\ [], do: block) do
    id = Keyword.get(opts, :id)
    # metadata = Keyword.get(opts, :metadata, %{})
    # base_parameters = get_base_arke_parameters(type)

    quote do
      id = unquote(id)
      caller = unquote(__CALLER__.module)

      unquote(block)

      @group %{
        id: id
      }
    end
  end

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
end

defmodule Arke.System.BaseGroup do
  use Arke.System.Group
end
