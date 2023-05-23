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

defmodule Arke.LinkManager do
  @moduledoc false
  @record_fields [:id, :data, :metadata, :inserted_at, :updated_at]

  alias Arke.Boundary.ArkeManager
  alias Arke.QueryManager
  alias Arke.Core.Unit

  def add_node(project, %Unit{} = parent, %Unit{} = child, type \\ "link", metadata \\ %{}) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)

    QueryManager.create(project, arke_link,
      parent_id: Atom.to_string(parent.id),
      child_id: Atom.to_string(child.id),
      type: type,
      metadata: metadata
    )
  end

  def delete_node(project, parent, child, type, metadata \\ %{}) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)

    # TODO: handle custom exception
    with %Arke.Core.Unit{} = link <-
           Arke.QueryManager.query(project: project, arke: arke_link)
           |> Arke.QueryManager.filter(:parent_id, :eq, Atom.to_string(parent.id), false)
           |> Arke.QueryManager.filter(:child_id, :eq, Atom.to_string(child.id), false)
           |> Arke.QueryManager.filter(:type, :eq, type, false)
           |> Arke.QueryManager.filter(:metadata, :eq, metadata, false)
           |> Arke.QueryManager.one() do
      case Arke.QueryManager.delete(project, link) do
        {:ok, _} -> {:ok, nil}
        {:error, msg} -> {:error, msg}
      end
    else
      _ -> raise "link not found"
    end
  end
end
