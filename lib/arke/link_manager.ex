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
  alias Arke.Utils.ErrorGenerator, as: Error
  alias Arke.QueryManager
  alias Arke.Core.Unit
  alias Arke.Core.Query

  defmodule LinkData do
    @enforce_keys [:parent_id, :child_id, :type]
    defstruct [:parent_id, :child_id, :type, metadata: %{}]

    def to_map(link_data) do
      Map.take(link_data, [:parent_id, :child_id, :type, :metadata])
    end
  end

  def add_node(project, %Unit{} = parent, %Unit{} = child, type \\ "link", metadata \\ %{}) do
    arke_link = ArkeManager.get(:arke_link, project)

    case check_link(project, parent, child, arke_link) do
      {_, nil} ->
        QueryManager.create(project, arke_link,
          parent_id: Atom.to_string(parent.id),
          child_id: Atom.to_string(child.id),
          type: type,
          metadata: metadata
        )

      {:ok, _} ->
        Error.create(:link, "link already exists")
    end
  end

  def add_node(project, parent, child, type, metadata)
      when is_binary(parent) and is_binary(child) do
    with %Unit{} = unit_parent <- QueryManager.get_by(id: parent, project: project),
         %Unit{} = unit_child <- QueryManager.get_by(id: child, project: project) do
      add_node(project, unit_parent, unit_child, type, metadata)
    else
      _ -> Error.create(:link, "parent: `#{parent}` or child: `#{child}` not found")
    end
  end

  def add_node(_project, _parent, _child, _type, _metadata),
    do: Error.create(:link, "invalid parameters")

  def add_node_bulk(project, link_list) do
    arke_link = ArkeManager.get(:arke_link, project)

    with {valid, errors} <- validate_units(project, arke_link, link_list),
         {valid, errors} <- validate_existing(project, arke_link, valid, errors),
         {:ok, inserted_count, valid, insert_errors} <-
           QueryManager.create_bulk(project, arke_link, prepare_link_data(valid), []) do
      {:ok, inserted_count, valid, errors ++ insert_errors}
    else
      {:error, errors} -> {:error, errors}
    end
  end

  def update_node(project, %Unit{} = parent, %Unit{} = child, type, metadata) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)

    case check_link(project, parent, child, arke_link) do
      {:error, _} -> Error.create(:link, "link not found")
      {:ok, link} -> QueryManager.update(link, metadata: metadata, type: type)
    end
  end

  def update_node(project, parent, child, type, metadata)
      when is_binary(parent) and is_binary(child) do
    unit_parent = QueryManager.get_by(id: parent, project: project)
    unit_child = QueryManager.get_by(id: child, project: project)

    update_node(project, unit_parent, unit_child, type, metadata)
  end

  def update_node(_project, _parent, _child, _type, _metadata),
    do: Error.create(:link, "invalid parameters")

  def delete_node(project, %Unit{} = parent, %Unit{} = child, type, metadata \\ %{}) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)

    case check_link(project, parent, child, arke_link) do
      {:error, _} -> Error.create(:link, "link not found")
      {:ok, link} -> QueryManager.delete(project, link)
    end
  end

  def delete_node(project, parent, child, type, metadata)
      when is_binary(parent) and is_binary(child) do
    unit_parent = QueryManager.get_by(id: parent, project: project)
    unit_child = QueryManager.get_by(id: child, project: project)

    delete_node(project, unit_parent, unit_child, type, metadata)
  end

  def delete_node(_project, _parent, _child, _type, _metadata),
    do: Error.create(:link, "invalid parameters")

  def delete_node_bulk(project, link_list) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)
    {valid, _} = validate_units(project, arke_link, link_list)

    QueryManager.delete_bulk(project, existing_links(project, arke_link, valid))
  end

  defp check_link(project, parent, child, arke_link) do
    with %Arke.Core.Unit{} = link <-
           Arke.QueryManager.query(project: project, arke: arke_link)
           |> Arke.QueryManager.filter(:parent_id, :eq, Atom.to_string(parent.id), false)
           |> Arke.QueryManager.filter(:child_id, :eq, Atom.to_string(child.id), false)
           |> Arke.QueryManager.one(),
         do: {:ok, link},
         else: (_ -> {:error, nil})
  end

  @spec validate_units(atom(), Arke.t(), list()) :: {list(LinkData.t()), list(map())}
  defp validate_units(project, arke_link, link_list) do
    ids =
      Enum.flat_map(link_list, fn link ->
        case {link["parent_id"], link["child_id"]} do
          {parent, child} when is_binary(parent) and is_binary(child) ->
            [parent, child]

          {parent, _} when is_binary(parent) ->
            [parent]

          {_, child} when is_binary(child) ->
            [child]

          _ ->
            []
        end
      end)

    unit_list = QueryManager.filter_by(id__in: ids, project: project)
    unit_map = Map.new(unit_list, fn unit -> {Atom.to_string(unit.id), unit} end)

    Enum.reduce(link_list, {[], []}, fn link, {valid, errors} ->
      parent =
        case link["parent_id"] do
          %Unit{} = p -> p
          id -> Map.get(unit_map, id)
        end

      child =
        case link["child_id"] do
          %Unit{} = c -> c
          id -> Map.get(unit_map, id)
        end

      type = Map.get(link, "type", "link")
      metadata = Map.get(link, "metadata", %{})

      case {parent, child} do
        {nil, nil} ->
          {valid, [%{link: link, error: "invalid parent and child"} | errors]}

        {nil, _} ->
          {valid, [%{link: link, error: "invalid parent"} | errors]}

        {_, nil} ->
          {valid, [%{link: link, error: "invalid child"} | errors]}

        {p, c} ->
          {[
             %LinkData{
               parent_id: Atom.to_string(p.id),
               child_id: Atom.to_string(c.id),
               type: type,
               metadata: metadata
             }
             | valid
           ], errors}
      end
    end)
  end

  @spec existing_links(project :: atom(), arke_link :: Arke.t(), link_list :: list(LinkData.t())) ::
          list(Arke.Core.Unit.t())
  defp existing_links(project, arke_link, link_list) do
    parameters = ArkeManager.get_parameters(arke_link)
    parent_id = Enum.find(parameters, fn p -> p.id == :parent_id end)
    child_id = Enum.find(parameters, fn p -> p.id == :child_id end)
    type = Enum.find(parameters, fn p -> p.id == :type end)

    # todo: handle type default_string ?

    Arke.QueryManager.query(project: project, arke: arke_link)
    |> Arke.Core.Query.add_filter(
      :or,
      false,
      Enum.map(link_list, fn link ->
        Arke.Core.Query.new_filter(:and, false, [
          Arke.QueryManager.condition(parent_id, :eq, link.parent_id, false),
          Arke.QueryManager.condition(child_id, :eq, link.child_id, false),
          Arke.QueryManager.condition(type, :eq, link.type, false)
        ])
      end)
    )
    |> Arke.QueryManager.all()
  end

  @spec validate_existing(atom(), Arke.t(), list(LinkData.t()), list()) ::
          {list(LinkData.t()), list()}
  defp validate_existing(project, arke_link, link_list, errors) do
    existing =
      existing_links(project, arke_link, link_list)
      |> Enum.reduce(MapSet.new(), fn link, acc ->
        MapSet.put(acc, {link.data.parent_id, link.data.child_id, link.data.type})
      end)

    Enum.reduce(link_list, {[], errors}, fn link, {valid_acc, errors_acc} ->
      case MapSet.member?(existing, {link.parent_id, link.child_id, link.type}) do
        true -> {valid_acc, [LinkData.to_map(link) | errors_acc]}
        false -> {[LinkData.to_map(link) | valid_acc], errors_acc}
      end
    end)
  end

  @spec prepare_link_data(list(LinkData.t())) :: list(map())
  defp prepare_link_data(link_list) do
    Enum.map(link_list, &LinkData.to_map/1)
  end
end
