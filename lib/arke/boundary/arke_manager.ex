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

defmodule Arke.Boundary.ArkeManager do
  @moduledoc """
             This module manage the gen servers for the element specified in `Arke.Core.Arke`
             """ && false
  use Arke.UnitManager

  set_registry_name(:arke_registry)
  set_supervisor_name(:arke_supervisor)

  def before_create(%{id: id, data: data, metadata: unit_metadata} = unit, project) do
    unit = check_module(unit)
    # new_parameters =
    #   Enum.reduce(get_parameters(unit), [], fn %{id: parameter_id, metadata: parameter_metadata} = _,
    #                                       new_parameters ->
    #     case init_parameter(project, parameter_id, parameter_metadata) do
    #       {:error, msg} -> %{id: parameter_id, metadata: parameter_metadata}
    #       parameter -> [parameter | new_parameters]
    #     end
    #   end)

    # {Unit.update(unit, parameters: new_parameters), project}
    {unit, project}
  end

  def get_parameters(%{data: data, metadata: %{project: project}} = unit) do
    Enum.reduce(data.parameters, [], fn %{
                                          id: parameter_id,
                                          metadata: parameter_metadata
                                        },
                                        new_parameters ->
      # parameter = Enum.filter(parameters, fn %{id: id} -> id == parameter_id end)

      case init_parameter(project, parameter_id, parameter_metadata) do
        {:error, msg} -> new_parameters
        parameter -> [parameter | new_parameters]
      end
    end)
  end

  def get_parameter(%{id: id} = unit, project, parameter_id),
    do: get_parameter(id, project, parameter_id)

  def get_parameter(%{id: id, metadata: %{project: project}} = unit, parameter_id),
    do: get_parameter(id, project, parameter_id)

  def get_parameter(unit_id, project, parameter_id) when is_binary(parameter_id),
    do: get_parameter(unit_id, project, String.to_existing_atom(parameter_id))

  def get_parameter(unit_id, project, parameter_id) when is_atom(parameter_id) do
    case get(unit_id, project) do
      {:error, msg} ->
        nil

      %{id: id, metadata: %{project: project}} ->
        GenServer.call(via({id, project}), {:get_parameter, parameter_id})
    end
  end

  def get_parameter(unit_id, project, %Unit{} = parameter), do: parameter

  # Call get link
  def handle_call({:get_parameter, parameter_id}, _from, {%{data: data} = unit, project})
      when is_atom(parameter_id) do
    with %{id: id, metadata: metadata} <-
           Enum.find(data.parameters, {:error, "parameter id not found"}, fn f ->
             f.id == parameter_id
           end),
         %Unit{} = parameter <- init_parameter(project, id, metadata),
         do: {:reply, parameter, {unit, project}},
         else:
           ({:error, msg} ->
              {:reply, nil, {unit, project}})
  end

  defp check_module(%{__module__: nil} = unit),
    do: Unit.update(unit, __module__: Arke.System.Arke)

  defp check_module(unit), do: unit

  # defp link_init(project, :parameters, child_id, metadata) do
  #   case init_parameter(project, child_id, metadata) do
  #     {:error, msg} -> %{id: child_id, metadata: metadata}
  #     p -> p
  #   end
  # end

  defp init_parameter(project, id, metadata, p) do
    arke_id = Map.get(p, :arke, nil)

    metadata = Enum.into(metadata, %{})

    Unit.new(
      id,
      metadata,
      arke_id,
      nil,
      %{},
      nil,
      nil,
      nil
    )

    # Unit.update(parameter, metadata)
  end

  defp init_parameter(project, id, metadata) do
    case Arke.Boundary.ParamsManager.get(id, project) do
      {:error, msg} ->
        {:error, msg}

      parameter ->
        parameter = handle_init_p(id, parameter, metadata)
    end
  end

  defp handle_init_p(id, nil, metadata) do
    IO.inspect({id, metadata})
    nil
  end

  defp handle_init_p(id, parameter, metadata) do
    Unit.update(parameter, metadata)
  end
end
