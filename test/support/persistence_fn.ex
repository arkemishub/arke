defmodule Arke.Support.PersistenceFn do
  def create(roject, %{arke_id: arke_id} = unit) do
    {:ok, Arke.Core.Unit.update(unit, metadata: Map.merge(unit.metadata, %{project: project}))}
  end

  def update(project, %{arke_id: arke_id} = unit) do
    {:ok, Arke.Core.Unit.update(unit, metadata: Map.merge(unit.metadata, %{project: project}))}
  end

  def delete(project, %{arke_id: arke_id} = unit), do: {:ok, nil}
  def execute(query, _), do: nil
  def get_parameters(), do: []
  def create_project(%{arke_id: :arke_project, id: _id} = _unit), do: :ok
  def delete_project(%{arke_id: :arke_project, id: _id} = _unit), do: :ok
end
