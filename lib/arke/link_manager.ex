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

  alias Arke.Boundary.ArkeManager
  alias Arke.Utils.ErrorGenerator, as: Error
  alias Arke.QueryManager
  alias Arke.Core.Unit
  alias Arke.Core.Query
  alias Arke.Core.Link

  def add_node(project, parent, child, type \\ "link", metadata \\ %{}) do
    arke_link = ArkeManager.get(:arke_link, project)
    link = %{"parent" => parent, "child" => child, "type" => type, "metadata" => metadata}

    with {valid, _} <-
           validate_links(project, arke_link, [link]),
         {[link], _} <- validate_existing(project, arke_link, valid, []),
         do:
           QueryManager.create(project, arke_link,
             parent_id: link.parent_id,
             child_id: link.child_id,
             type: link.type,
             metadata: link.metadata
           ),
         else: (_ -> Error.create(:link, "link already exists"))
  end

  def add_node(_project, _parent, _child, _type, _metadata),
    do: Error.create(:link, "invalid parameters")

  def add_node_bulk(project, link_list) do
    arke_link = ArkeManager.get(:arke_link, project)

    with {valid, errors} <- validate_links(project, arke_link, link_list),
         {valid, errors} <- validate_existing(project, arke_link, valid, errors),
         {:ok, inserted_count, valid, insert_errors} <-
           QueryManager.create_bulk(project, arke_link, prepare_link_data(valid), []) do
      {:ok, inserted_count, valid, errors ++ insert_errors}
    else
      {:error, errors} -> {:error, errors}
    end
  end

  def update_node(project, parent, child, type, metadata) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)
    link = %{"parent" => parent, "child" => child, "type" => type, "metadata" => metadata}

    with {[valid_link], _} <- validate_links(project, arke_link, [link]),
         [existing_link] <- existing_links(project, arke_link, [valid_link]) do
      QueryManager.update(existing_link, metadata: metadata)
    else
      _ -> Error.create(:link, "link not found")
    end
  end

  def update_node(_project, _parent, _child, _type, _metadata),
    do: Error.create(:link, "invalid parameters")

  def update_node_bulk(project, link_list) do
    arke_link = ArkeManager.get(:arke_link, project)

    {valid, errors} = validate_links(project, arke_link, link_list)
    existing = existing_links(project, arke_link, valid)

    QueryManager.update_bulk(project, arke_link, existing, prepare_link_data(valid))
  end

  def delete_node(project, parent, child, type, metadata \\ %{}) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)
    link = %{"parent" => parent, "child" => child, "type" => type, "metadata" => metadata}

    with {[valid_link], _} <- validate_links(project, arke_link, [link]),
         [existing_link] <- existing_links(project, arke_link, [valid_link]) do
      QueryManager.delete(project, existing_link)
    else
      _ -> Error.create(:link, "link not found")
    end
  end

  def delete_node(_project, _parent, _child, _type, _metadata),
    do: Error.create(:link, "invalid parameters")

  def delete_node_bulk(project, link_list) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)
    {valid, _} = validate_links(project, arke_link, link_list)

    QueryManager.delete_bulk(project, existing_links(project, arke_link, valid))
  end

  @spec validate_links(atom(), Arke.t(), list()) :: {list(Link.t()), list(map())}
  defp validate_links(project, arke_link, [%Link{} | _] = link_list),
    do: {link_list, []}

  defp validate_links(project, arke_link, [%Unit{} | _] = unit_list) do
    links =
      Enum.map(unit_list, fn unit ->
        Link.load(project, unit)
      end)

    {links, []}
  end

  defp validate_links(project, arke_link, link_list) do
    Enum.reduce(link_list, {[], []}, fn link, {valid, errors} ->
      parent = link["parent"]
      child = link["child"]
      type = Map.get(link, "type", "link")
      metadata = Map.get(link, "metadata", %{})

      case {parent, child} do
        {parent, child} when is_binary(parent) and is_binary(child) ->
          {[Link.new(parent, child, type, metadata) | valid], errors}

        {nil, nil} ->
          {valid, [%{link: link, error: "invalid parent and child"} | errors]}

        {nil, _} ->
          {valid, [%{link: link, error: "invalid parent"} | errors]}

        {_, nil} ->
          {valid, [%{link: link, error: "invalid child"} | errors]}

        _ ->
          {valid, [%{link: link, error: "invalid parent and child format"} | errors]}
      end
    end)
  end

  @spec existing_links(project :: atom(), arke_link :: Arke.t(), link_list :: list(Link.t())) ::
          list(Arke.Core.Unit.t())

  defp existing_links(_project, _arke_link, []), do: []

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

  @spec validate_existing(atom(), Arke.t(), list(Unit.t()), list()) ::
          {list(Link.t()), list()}
  defp validate_existing(project, arke_link, link_list, errors) do
    existing =
      existing_links(project, arke_link, link_list)
      |> Enum.reduce(MapSet.new(), fn link, acc ->
        MapSet.put(acc, {link.data.parent_id, link.data.child_id, link.data.type})
      end)

    Enum.reduce(link_list, {[], errors}, fn link, {valid_acc, errors_acc} ->
      case MapSet.member?(existing, {link.parent_id, link.child_id, link.type}) do
        true -> {valid_acc, [data_to_map(link) | errors_acc]}
        false -> {[data_to_map(link) | valid_acc], errors_acc}
      end
    end)
  end

  @spec prepare_link_data(list(Link.t())) :: list(map())
  defp prepare_link_data(link_list) do
    Enum.map(link_list, &data_to_map/1)
  end

  defp data_to_map(link) do
    Map.take(link, [:parent_id, :child_id, :type, :metadata])
  end
end
