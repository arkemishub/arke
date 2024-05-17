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
  @moduledoc """
  Core module which handle all the management functions for the Unit of a Group.
  See `Arke.Example.System.MacroGroup` to get a list of all the available functions.
  """

  @doc """
  This macro is used whenever we want to edit the default behaviour

        use Arke.System.Group
  """
  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :group, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :parameters, accumulate: true, persist: false)
      Module.register_attribute(__MODULE__, :system_group, accumulate: false, persist: true)
      Module.put_attribute(__MODULE__, :system_group, true)

      import unquote(__MODULE__),
        only: [group: 1, group: 2, parameter: 3, parameter: 2]

      # Return the Group struct for the given module
      @doc false
      def group_from_attr(), do: Keyword.get(__MODULE__.__info__(:attributes), :group, []) |> List.first()

      @doc false
      def is_group?(), do: Keyword.get(__MODULE__.__info__(:attributes), :system_group, []) |> List.first()

      @doc false
      def on_unit_load(arke, data, _persistence_fn), do: {:ok, data}

      @doc false
      def before_unit_load(_arke, data, _persistence_fn), do: {:ok, data}

      @doc false
      def on_unit_validate(_arke, unit), do: {:ok, unit}

      @doc false
      def before_unit_validate(_arke, unit), do: {:ok, unit}

      @doc false
      def on_unit_create(_arke, unit), do: {:ok, unit}

      @doc false
      def before_unit_create(_arke, unit), do: {:ok, unit}

      @doc false
      def on_unit_struct_encode(unit, _), do: {:ok, unit}

      @doc false
      def on_unit_update(_arke, unit), do: {:ok, unit}

      @doc false
      def before_unit_update(_arke, unit), do: {:ok, unit}

      @doc false
      def on_unit_delete(_arke, unit), do: {:ok, unit}

      @doc false
      def before_unit_delete(_arke, unit), do: {:ok, unit}

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
                     before_unit_delete: 2
    end
  end


  ######################################################################################################################
  # Group MACRO #########################################################################################################
  ######################################################################################################################

  @doc """
  Macro to manager a group and its related functions

  ## Example
      group id: :some_id do
      end

  From now on all the overridable functions can be edited and all the public functions will be used as API custom function
  """

  @spec group(args :: list(), Macro.t()) :: %{}
  defmacro group(opts \\ [], do: block) do
    id = Keyword.get(opts, :id)


    quote do
      id = unquote(id)
      caller = unquote(__CALLER__.module)

      unquote(block)

      @group %{
        id: id,
      }
    end
  end

  ######################################################################################################################
  # END ARKE MACRO #####################################################################################################
  ######################################################################################################################

  ######################################################################################################################
  # PARAMETER MACRO ####################################################################################################
  ######################################################################################################################

  @doc  false
  @spec parameter(id :: atom(), type:: atom(), opts :: list()) :: Macro.t()
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
