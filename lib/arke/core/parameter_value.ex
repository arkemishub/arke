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

defmodule Arke.Core.ParameterValue do
  @moduledoc false

  use Arke.System
  alias Arke.Boundary.ArkeManager
  alias Arke.QueryManager

  arke id: :parameter_value, label: "Parameter_value", type: "table" do
    parameter(:value, :dict, required: true, nullable: true, persistence: "table_column")
    parameter(:datetime, :datetime, is_primary: true, required: true, persistence: "table_column")
    parameter(:parameter_id, :string, is_primary: true, required: true, persistence: "table_column")
    parameter(:unit_id, :string, is_primary: true, required: true, persistence: "table_column")
#    parameter(:inserted_at, :datetime, required: true, persistence: "table_column")

    parameter(:metadata, :dict,
      default_dict: %{},
      persistence: "table_column"
    )
  end

  def add_value(project, unit_id, parameter_id, datetime, value, metadata) do
    arke = ArkeManager.get(:parameter_value, project)

    data = [
      value: value,
      datetime: datetime,
      parameter_id: parameter_id,
      unit_id: unit_id,
      metadata: metadata
    ]

    try do
      QueryManager.create(project, arke, data)
    rescue
      e ->
        IO.inspect(e)
        u = QueryManager.get_by(project: project, arke: arke, unit_id: unit_id, parameter_id: parameter_id, datetime: datetime)
        QueryManager.update(u, data)
    end
  end

end
