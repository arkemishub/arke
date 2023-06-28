defmodule Arke.Support.PersistenceFn do
  def create(project, %{arke_id: arke_id} = unit) do
    {:ok, Arke.Core.Unit.update(unit, metadata: Map.merge(unit.metadata, %{project: project}))}
  end

  def update(project, %{arke_id: arke_id} = unit) do
    {:ok, Arke.Core.Unit.update(unit, metadata: Map.merge(unit.metadata, %{project: project}))}
  end

  def delete(project, %{arke_id: arke_id} = unit), do: {:ok, nil}
  def execute(query, :all), do: {:execute, :all}
  def execute(query, :one), do: nil
  def execute(query, :raw), do: {:execute, :raw}
  def execute(query, :count), do: {:execute, :count}
  def execute(query, :pseudo_query), do: {:execute, :pseudo_query}
  def get_parameters(), do: []
  def create_project(%{arke_id: :arke_project, id: _id} = _unit), do: :ok
  def delete_project(%{arke_id: :arke_project, id: _id} = _unit), do: :ok
end
