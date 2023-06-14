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

defmodule Arke.Examples.Starter do
  @moduledoc """
               Module to start all the defaults gen server
             """ && false
  alias Arke.Boundary.{ArkeManager}

  @doc """
  It starts all the defaults gen server which will contain all the {arke_struct}
  """
  def init() do
    Enum.each([:arke], fn app ->
      {:ok, modules} = :application.get_key(app, :modules)

      Enum.each(modules, fn mod ->
        is_arke = Keyword.get(mod.__info__(:attributes), :is_arke, false)
        init_arke_by_struct(mod, is_arke)
      end)
    end)

    Arke.Boundary.ParameterManager.get_from_persistence()
    init_arke_by_persistence()
    init_arke_parameters_by_persistence()
  end

  defp init_arke_by_struct(struct, [true]) do
    args = struct.get_info()

    parameters =
      Enum.reduce(struct.get_parameters(), [], fn [p], parameters ->
        parameter = Arke.Core.Parameter.new(p)
        Arke.Boundary.ParamsManager.create(parameter, :arke_system)
        Arke.Boundary.ParameterManager.create(parameter, :arke_system)
        [parameter | parameters]
      end)

    args = Keyword.put_new(args, :parameters, parameters)
    ArkeManager.set_manager(Arke.Core.Arke.new(args), :arke_system)
  end

  defp init_arke_by_struct(_, _), do: nil

  defp init_arke_by_persistence() do
    arke = ArkeManager.get(:arke, :arke_system)
    arkes = Arke.QueryManager.filter_by(project: :arke_system, arke: "arke")

    Enum.map(arkes, fn %{data: data} ->
      ArkeManager.create(
        Arke.Core.Arke.new(Map.merge(data, %{parameters: arke.parameters})),
        :arke_system
      )
    end)
  end

  defp init_arke_parameters_by_persistence() do
    arke_link = ArkeManager.get(:arke_link, :arke_system)

    arke_parameters =
      Arke.QueryManager.query(arke: arke_link)
      |> Arke.QueryManager.where(type: "parameter")
      |> Arke.QueryManager.all()

    Enum.map(arke_parameters, fn %{data: data} ->
      parent_id = String.to_existing_atom(data.parent_id)
      child_id = String.to_existing_atom(data.child_id)
      ArkeManager.add_parameter(parent_id, :arke_system, child_id, data.metadata)
    end)
  end

  # defp schemas() do
  #   schemas = [
  #     {
  #       :default,
  #       [id: :arke_schema, label: "Arke Schema", type: :table],
  #       [
  #         [id: :id, label: "ID", type: :string, is_primary: true, metadata: %{required: true}],
  #         [id: :label, label: "Label", type: :string, metadata: %{required: true}],
  #         [id: :active, label: "Active", type: :boolean, metadata: %{default: true}],
  #         [id: :metadata, label: "Metadata", type: :map, metadata: %{default: %{}}],
  #         [id: :type, label: "Type", type: :string, metadata: %{default: :string}],
  #         [id: :inserted_at, label: "Inserted at", type: :datetime, metadata: %{default: DatetimeHandler.now(:datetime)}],
  #         [id: :updated_at, label: "Updated at", type: :datetime, metadata: %{default: DatetimeHandler.now(:datetime)}],
  #       ]
  #     },
  #     {
  #       :default,
  #       [id: :arke_field, label: "Arke Field", type: :table],
  #       [
  #         [id: :id, label: "ID", type: :string, is_primary: true],
  #         [id: :label, label: "Label", type: :string],
  #         [id: :type, label: "Type", type: :string],
  #         [id: :metadata, label: "Metadata", type: :map],
  #         [id: :format, label: "Format", type: :string],
  #         [id: :is_primary, label: "Is Primary", type: :boolean],
  #         [id: :inserted_at, label: "Inserted at", type: :datetime],
  #         [id: :updated_at, label: "Updated at", type: :datetime],
  #       ]
  #     },
  #     {
  #       :default,
  #       [id: :arke_schema_field, label: "Arke Schema Field", type: :table],
  #       [
  #         [id: :arke_schema_id, label: "Arke schema id", type: :string, is_primary: true],
  #         [id: :arke_field_id, label: "Arke field id", type: :string, is_primary: true],
  #         [id: :metadata, label: "Metadata", type: :map],
  #       ]
  #     },
  #     {
  #       :default,
  #       [id: :arke_record, label: "Arke Record", type: :table],
  #       [
  #         [id: :id, label: "ID", type: :string, is_primary: true],
  #         [id: :arke_schema_id, label: "Arke schema id", type: :string],
  #         [id: :data, label: "Data", type: :map],
  #         [id: :metadata, label: "Metadata", type: :map],
  #         [id: :inserted_at, label: "Inserted at", type: :datetime],
  #         [id: :updated_at, label: "Updated at", type: :datetime],
  #       ]
  #     },
  #     {
  #       :test,
  #       [id: :arke_schema, label: "Arke Schema", type: :arke_unit],
  #       [
  #         [id: :id, label: "ID", type: :string, is_primary: true],
  #         [id: :label, label: "Label", type: :string],
  #         [id: :active, label: "Active", type: :boolean],
  #         [id: :metadata, label: "Metadata", type: :map],
  #         [id: :type, label: "Type", type: :string],
  #         [id: :inserted_at, label: "Inserted at", type: :datetime],
  #         [id: :updated_at, label: "Updated at", type: :datetime],
  #       ]
  #     },
  #   ]
  # end
end
