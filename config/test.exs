import Config

config :arke,
  persistence: %{
    arke_postgres: %{
      create: &Arke.Support.PersistenceFn.create/2,
      update: &Arke.Support.PersistenceFn.update/2,
      delete: &Arke.Support.PersistenceFn.delete/2,
      execute_query: &Arke.Support.PersistenceFn.execute/2,
      get_parameters: &Arke.Support.PersistenceFn.get_parameters/0,
      create_project: &Arke.Support.PersistenceFn.create_project/1,
      delete_project: &Arke.Support.PersistenceFn.delete_project/1
    }
  }
