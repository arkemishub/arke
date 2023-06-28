ExUnit.start()
Arke.Support.CreateArke.support_parameter()

create_support_arke = fn ->
  alias Arke.Core.Unit
  alias Arke.Boundary.{ArkeManager, GroupManager}

  mod = Arke.Support.CreateArke

  %{id: id, data: data, metadata: metadata} = mod.arke_from_attr
  unit = Unit.new(id, data, :arke, nil, metadata, nil, nil, mod)

  ArkeManager.create(unit, :arke_system)

  Enum.map(mod.groups_from_attr, fn %{id: parent_id, metadata: link_metadata} ->
    GroupManager.add_link(parent_id, :arke_system, :arke_list, id, link_metadata)
  end)
end

create_support_arke.()
