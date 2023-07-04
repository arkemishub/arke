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

defmodule Arke.Core.Arke do
  @moduledoc """
  Defines the skeleton of an Arke by defining its characteristics and the various parameters of which it is composed
  """
  defstruct [:id, :label, :active, :type, :parameters]

  use Arke.System
  alias Arke.Core.Parameter
  alias Arke.Boundary.ArkeManager

  arke id: :arke do
    group(:arke_or_group)

    parameter(:label, :string, required: true)
    parameter(:active, :boolean, required: false, default_boolean: true)
    parameter(:type, :string, required: true, default_string: "arke")

    parameter(:parameters, :link,
      multiple: true,
      arke_or_group_id: "parameter",
      connection_type: "parameter",
      filter_keys: ["arke_id", "id", "label"],
      depth: 0,
      default_link: []
    )
  end

  def on_create(arke, unit) do
    unit = check_base_parameters(arke, unit)
    ArkeManager.create(unit)
    {:ok, unit}
  end

  def on_update(_, %{id: id, metadata: %{project: project}} = unit) do
    ArkeManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_delete(_, unit) do
    ArkeManager.remove(unit)
    {:ok, unit}
  end

  def check_base_parameters(arke, %{data: %{parameters: []}} = unit),
    do: Arke.Core.Unit.update(unit, parameters: base_parameters(arke, unit))

  def check_base_parameters(_, unit), do: unit

  def base_parameters(arke, %{data: %{parameters: []}} = unit), do: base_parameters(arke)
  def base_parameters(_, unit), do: unit.data.parameters

  def base_parameters(arke) do
    Enum.reduce(arke.data.parameters, [], fn %{metadata: metadata} = p, arke_parameters ->
      check_arke_base_parameter(p, metadata |> Enum.into(%{}), arke_parameters)
    end)
  end

  def check_arke_base_parameter(parameter, %{:persistence => "table_column"}, parameters),
    do: [parameter | parameters]

  def check_arke_base_parameter(_, _, parameters), do: parameters
end
