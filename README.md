# Arke

![Arke](https://github.com/arkemishub/arke/assets/81776297/7a04d11b-5cd0-4349-8621-d19cf0274585)

## Documentation

In depth documentation can be found at [https://hexdocs.pm/arke](https://hexdocs.pm/arke), while a more generic can be found [here](https://docs.arkehub.com/docs)

## Installation
The package can be installed by adding `arke` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:arke, "~> 0.1.0"}
  ]
end
```

Also add in our project the configuration below based on your persistence. In this case we use `arke_postgres`
```
config :arke,
    persistence: %{
        arke_postgres: %{
            init: &ArkePostgres.init/0,
            create: &ArkePostgres.create/2,
            update: &ArkePostgres.update/2,
            delete: &ArkePostgres.delete/2,
            execute_query: &ArkePostgres.Query.execute/2,
            create_project: &ArkePostgres.create_project/1,
            delete_project: &ArkePostgres.delete_project/1,
            repo: ArkePostgres.Repo,
        }
    }
```
This configuration is used to apply all the CRUD operations in the `Arke.QueryManager` module