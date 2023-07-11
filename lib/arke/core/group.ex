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

defmodule Arke.Core.Group do
  @moduledoc """
    Defines the structure of a Group in which more than one Arke will be grouped
  """

  use Arke.System
  alias Arke.Boundary.GroupManager
  alias Arke.Core.Unit

  arke do
    group(:arke_or_group)

    parameter(:label, :string, required: false)
    parameter(:description, :string, required: false)

    parameter(:arke_list, :link,
      multiple: true,
      arke_or_group_id: "arke",
      connection_type: "group",
      depth: 0,
      default_link: []
    )
  end

  def on_create(_, unit) do
    group = Unit.update(unit, arke_list: [])
    GroupManager.create(group)
    {:ok, unit}
  end

  def on_update(_, unit) do
    GroupManager.create(unit)
    {:ok, unit}
  end

  def on_delete(_, unit) do
    GroupManager.remove(unit)
    {:ok, unit}
  end
end
