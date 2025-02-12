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

defmodule Arke.Core.Link do
  @moduledoc false

  use Arke.System
  alias Arke.LinkManager
  alias Arke.Boundary.{ArkeManager, GroupManager}

  arke id: :arke_link do
  end

  @enforce_keys [:parent_id, :child_id, :type]
  defstruct [:parent_id, :child_id, :type, metadata: %{}]

  def new(parent_id, child_id, type, metadata \\ %{}) do
    __struct__(parent_id: parent_id, child_id: child_id, type: type, metadata: metadata)
  end

  def load(arke_link, %Arke.Core.Unit{arke_id: :arke_link} = unit) do
    new(unit.data.parent_id, unit.data.child_id, unit.data.type, unit.metadata)
  end

  def load(arke_link, opts) do
    {parent_id, opts} = Map.pop(opts, :parent_id, nil)
    {child_id, opts} = Map.pop(opts, :child_id, nil)
    {type, opts} = Map.pop(opts, :type, nil)
    {metadata, opts} = Map.pop(opts, :metadata, arke_link.metadata)

    new(parent_id, child_id, type, metadata)
  end

  def on_create(
        _,
        %{
          data: %{type: "parameter", parent_id: parent_id, child_id: child_id},
          metadata: %{project: project} = metadata
        } = unit
      ) do
    ArkeManager.add_link(
      String.to_existing_atom(parent_id),
      project,
      :parameters,
      String.to_existing_atom(child_id),
      metadata
    )

    {:ok, unit}
  end

  def on_create(
        _,
        %{
          data: %{type: "group", parent_id: parent_id, child_id: child_id},
          metadata: %{project: project} = metadata
        } = unit
      ) do
    GroupManager.add_link(
      String.to_existing_atom(parent_id),
      project,
      :arke_list,
      String.to_existing_atom(child_id),
      metadata
    )

    {:ok, unit}
  end

  def on_create(
        _,
        %{
          data: %{type: type, parent_id: parent_id, child_id: child_id},
          metadata: %{project: project} = metadata
        } = unit
      ) do
    {:ok, unit}
  end

  def on_update(
        _,
        %{
          data: %{type: "parameter", parent_id: parent_id, child_id: child_id},
          metadata: %{project: project} = metadata
        } = unit
      ) do
    ArkeManager.update_parameter(parent_id, child_id, project, metadata)
    {:ok, unit}
  end

  def on_delete(
        _,
        %{
          data: %{type: "parameter", parent_id: parent_id, child_id: child_id},
          metadata: %{project: project} = metadata
        } = unit
      ) do
    ArkeManager.remove_link(
      String.to_existing_atom(parent_id),
      project,
      :parameters,
      String.to_existing_atom(child_id)
    )

    {:ok, unit}
  end

  def on_delete(
        _,
        %{
          data: %{type: "group", parent_id: parent_id, child_id: child_id},
          metadata: %{project: project} = metadata
        } = unit
      ) do
    GroupManager.remove_link(
      String.to_existing_atom(parent_id),
      project,
      :arke_list,
      String.to_existing_atom(child_id)
    )

    {:ok, unit}
  end

  def on_delete(
        _,
        %{
          data: %{type: type, parent_id: parent_id, child_id: child_id},
          metadata: %{project: project} = metadata
        } = unit
      ) do
    {:ok, unit}
  end
end
