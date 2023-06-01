defmodule Arke.RepoCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Arke.Boundary.{ArkeManager, ParameterManager, GroupManager}
      alias Arke.QueryManager
      alias Arke.Core.Unit
      alias Arke.LinkManager
      alias Arke.Core.Query
      alias Arke.StructManager

      import Arke.RepoCase

      # and any other stuff
    end
  end

    :ok
  end
end
