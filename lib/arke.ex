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

defmodule Arke do
  alias Arke.Validator
  alias Arke.Core.Unit
  alias Arke.Boundary.{ArkeManager, GroupManager, ParameterManager}
  alias Arke.Core.Parameter

  # trovare il modo di prendere tutti i parametri (query

  def init(), do: :ok


  defp get_arke_modules() do
    Enum.reduce(:application.loaded_applications(), [], fn {app, _, _}, arke_list ->
      {:ok, modules} = :application.get_key(app, :modules)

      module_arke_list =
        Enum.reduce(modules, [], fn mod, mod_arke_list ->
          is_arke =
            Code.ensure_loaded?(mod) and :erlang.function_exported(mod, :arke_from_attr, 0) and
              mod.arke_from_attr != nil and mod.arke_from_attr.remote == true

          mod_arke_list = check_arke_module(mod, mod_arke_list, is_arke)
        end)

      arke_list ++ module_arke_list
    end)
  end

  defp get_module(data,type) do
    # get all the arke modules which has the arke macro defined
    # find the right module for the given data and return it
    arke_module_list = Enum.reduce(:application.loaded_applications(), [], fn {app, _, _}, arke_list ->
      {:ok, modules} = :application.get_key(app, :modules)

      function_name = get_module_fn(type)

      module_arke_list =
        Enum.reduce(modules, [], fn mod, mod_arke_list ->
          if Code.ensure_loaded?(mod) and :erlang.function_exported(mod, function_name, 0) and
             apply(mod, function_name,[]) != nil do
            [%{module: mod, arke_id: apply(mod, function_name,[]).id} | mod_arke_list]
          else
            mod_arke_list
          end
        end)


      arke_list ++ module_arke_list
    end)
    Enum.find(arke_module_list,%{module: nil, arke_id: nil}, fn k ->
    if is_map(k) do
      to_string(k.arke_id) == to_string(Map.get(data,:id))
                 end
    end)[:module]
  end
  defp get_module_fn("arke"), do: :arke_from_attr
  defp get_module_fn("group"), do: :group_from_attr

  defp check_arke_module(mod, arke_list, true) do
    %{id: id, data: data, metadata: metadata} = mod.arke_from_attr
    unit = Unit.new(id, data, :arke, nil, metadata, nil, nil, mod)

    ArkeManager.create(unit, :arke_system)

    Enum.map(mod.groups_from_attr, fn %{id: parent_id, metadata: link_metadata} ->
      GroupManager.add_link(parent_id, :arke_system, :arke_list, id, link_metadata)
    end)

    [mod | arke_list]
  end

  defp check_arke_module(_, arke_list, false), do: arke_list

  def handle_manager(_data,_project,_arke_id,_error\\[])
  def handle_manager([data | t],project,:parameter,error)do
    {type, updated_data} = Map.pop(data,:type)
    updated_error = start_manager(updated_data,type,project,ParameterManager,nil)
    handle_manager(t,project, :parameter,updated_error ++ error)
  end

  def handle_manager([data | t],project,:arke,error) do
    {flatten_data,other} = Map.pop(data,:data,%{})
    updated_data = Map.merge(flatten_data,other)
                   |> Map.put(:type,Map.get(data,:type,"arke"))
                   |> Map.put_new(:active,true)
    final_data = Map.replace(updated_data,:parameters,parse_arke_parameter(updated_data,project))
    module = get_module(final_data,"arke")
    updated_error = start_manager(final_data,"arke",project,ArkeManager, module)
    handle_manager(t,project, :arke,updated_error ++ error)
  end

  def handle_manager([data | t],project,:group,error)do
    #todo: check if in arke_list we need also metadata besides the id
    loaded_list = Enum.reduce(Map.get(data,:arke_list,[]),[], fn id,acc ->
      case Arke.Boundary.ArkeManager.get(id, project) do
        {:error, _msg} ->
          [%{context: :arke_list_group , message: "no manager has been found for: `#{id}` in `#{project}`"} | error]
        arke ->
          [arke | acc]
      end

    end)
    final_data= Map.put_new(data,:metadata,%{})
                |> Map.put(:arke_list,loaded_list)
    module = get_module(final_data,"group")
    updated_error = start_manager(final_data,"group",project,GroupManager,module)
    if length(updated_error) == 0 do
      Enum.each(final_data.arke_list, fn arke -> link_arke_group(final_data.id,project,arke) end)

    end
    handle_manager(t,project, :group,updated_error ++ error)
  end

  defp link_arke_group(group_id,project, arke) when is_binary(arke), do: link_arke_group(group_id,project,%{id: arke, metadata: %{}})
  defp link_arke_group(group_id,project, arke) do
    GroupManager.add_link(group_id, project, :arke_list, arke.id, arke.metadata)
  end

  def handle_manager([],_project,_arke_id,error),do: error
  defp start_manager(_data,_type,_project, _manager, _module,_error\\[])

  defp start_manager(data,type,project, manager, module,error) do
    case Map.pop(data,:id,nil) do
      {nil, _updated_data} -> [%{context: :manager , message: "key id not found"} | error]
      {id, updated_data} ->  case manager.create(
                                    Unit.new(
                                      String.to_atom(id),
                                      updated_data,
                                      String.to_atom(type),
                                      nil,
                                      %{},
                                      nil,
                                      nil,
                                      module
                                    ),
                                    project
                                  ) do
                               %Unit{} = _unit ->
                                 error
                               _ ->[%{context: :manager , message: "cannot start manager for: `#{id}`"} | error]
                             end
    end

  end
  defp parse_arke_parameter(data,project) do

    Map.get(data,:parameters) |> Enum.reduce([], fn param,acc ->
      # todo: fare controllo per cui se esce tbd (sarà poi nil) scrivere sul file che la chiave  id manca
      converted = Map.update(param,:id, "tbd", &String.to_atom(&1))
      id = converted[:id]
      arke = ParameterManager.get(id,project)
      [ Map.put(converted,:arke, arke.arke_id) | acc]
    end)
  end
end
