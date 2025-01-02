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

defmodule Arke.Boundary.FileManager do
  @moduledoc """
  Store the signed url until expiration to avoid useless requests
  """
  use Arke.Boundary.UnitManager
  alias Arke.Core.Unit

  manager_id(:file_manager)

  def before_create(unit, opts) when is_list(opts), do: before_create(unit, Enum.into(opts, %{}))

  def before_create(%{metadata: %{project: project}} = unit, opts) do
    new_unit = Unit.update(unit, runtime_data: Map.merge(unit.runtime_data, opts))
    {new_unit, project}
  end
end
