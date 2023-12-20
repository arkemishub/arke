defmodule Mix.Tasks.Arke.SeedProject do
  @moduledoc """
  Seed a given project in the database using file data.

  ## Examples

      $ mix arke.seed_project --project my_project1 --p myproject2
      $ mix arke.seed_project --all

  ## Command line options

  * `--project` - The id of the project to seed. It could be passed multiple times
  * `--all` - Seed all the project found in the database
  * `--format` -The format of the file used to import the data.One of:
      * `json` Default
  * `--persistence` - The persistence to use. One of:
      * `arke_postgres` - via https://github.com/elixir-ecto/postgrex (Default)
  """
  use Mix.Task
  alias Arke.QueryManager
  alias Arke.LinkManager
  alias Arke.Utils.ErrorGenerator, as: Error
  alias Arke.Boundary.{ArkeManager, ParameterManager, GroupManager}

  alias Arke.Core.Unit
  @decode_keys ["arke", "parameter", "group", "link"]
  @supported_format ["json", "yml", "yaml"]
  @shortdoc "Seed a prjoect"
  @persistence_repo ["postgres"]

  @switches [
    project: :string,
    all: :boolean,
    format: :string,
    persistence: :string,
  ]
  @aliases [
    p: :project,
    A: :all,
    f: :format,
    ps: :persistence,
  ]

  @impl true
  def run(args) do

    case OptionParser.parse!(args, strict: @switches, aliases: @aliases) do
      {_opts, []} ->
        Mix.Tasks.Help.run(["arke.seed_project"])
      {opts, _args} ->
      persistence = parse_persistence!(opts[:persistence] || "arke_postgres")
        [persistence]
        |> Enum.each(&Application.ensure_all_started/1)

        case start_repo(persistence) do
          {:ok, pid} ->
            opts |> parse_file()
            Process.exit(pid, :normal)
            :ok

          {:error, _} ->
            opts |> parse_file()
            :ok
        end

    end

  end



  defp parse_persistence!("arke_postgres"), do: :arke_postgres
  defp parse_persistence!(ps), do: Mix.raise("Invalid persistence: `#{ps}`\nSupported persistence are: #{Enum.join(@persistence_repo, " | ")}")

  defp start_repo(persistence) do
    repo = Application.get_env(:arke, :persistence)
    repo[String.to_atom(persistence)].start_link() end

  defp parse_file(opts)  do

    format = opts[:format] || "json"
    check_format!(format)
    all = opts[:all] || false
    project_list = get_project(opts[:project] || ["arke_system"], all)

    # get core file to decode (arke)
    core_registry = arke_registry("arke", format)
    core_data = parse(core_registry)

    #get all other arke_deps registry files
    arke_deps_registry = get_arke_deps_registry(format)
    arke_deps_data = parse(arke_deps_registry)


    # todo: decidere chiave da mettere nei metadata così da identificare gli tutto ciò che viene creato e far si che da console non si possa cancellare
    # i put andranno modificati di conseguenza in modo da rendere qeusta chiave non modificabile e fissa

    file_list = Path.wildcard("./lib/registry/*.#{format}")
    raw_data = parse(file_list)
    parsed_project = parse_project(project_list)
    parameter_list = Map.get(raw_data, "parameter", []) ++ Map.get(arke_deps_data, "parameter", [])
    arke_list = Map.get(raw_data, "arke", []) ++ Map.get(arke_deps_data, "arke", [])
    group_list = Map.get(raw_data, "group", []) ++ Map.get(arke_deps_data, "group", [])
    link_list = Map.get(raw_data, "link", []) ++ Map.get(arke_deps_data, "list", [])

    Enum.each(parsed_project, fn project ->
      # start core manager before create everything
      error_parameter_manager = start_manager(Map.get(core_data,"parameter", []),project,:parameter)
      error_arke_manager = start_manager(Map.get(core_data,"arke", []),project,:arke)
      error_group_manager = start_manager(Map.get(core_data,"group", []),project,:group)
      error_parameter = handle_parameter(parameter_list, project,[])
      error_arke = handle_arke(Map.get(raw_data, "arke", []), project,[])
      error_group = handle_group(Map.get(raw_data, "group", []), project,[])
      error_link = handle_link(Map.get(raw_data, "link", []), project,[])
    end)
  end

  defp arke_registry(package_name,format) do
    # Get arke's dependecies based on the env path.
    env_var = System.get_env()
   core_registry_file = case Enum.find(env_var,fn  {k,_v}-> String.contains?(String.downcase(k), "ex_dep_#{package_name}_path") end) do
      {_package_name, local_path}  ->
        Path.wildcard("#{local_path}/lib/registry/*.#{format}")
      nil -> Path.wildcard("./**/arke*/**/registry/*.#{format}")
    end

  end

  defp get_project(project_list, true) do
    QueryManager.filter_by(arke_id: :arke_project, project: :arke_system)
    |> Enum.map(project_list, fn unit -> to_string(unit.id) end)
  end

  defp get_project(opts, _all), do: (if is_list(opts), do: opts, else: [opts])

  defp check_format!(format) when format in @supported_format, do: format
  defp check_format!(format), do: Mix.raise("Invalid format: `#{format}`\nSupported format are: #{Enum.join(@supported_format, " | ")}")

  # get all the registry file for all the arke_deps except arke itself which is used alone
  defp get_arke_deps_registry(format) do
    Enum.reduce(Mix.Project.config() |> Keyword.get(:deps, []),[], fn tuple,acc ->
      name = List.first(Tuple.to_list(tuple))
      if name != :arke and String.contains?(to_string(name),"arke") do
        arke_registry(to_string(name),format) ++ acc
      else acc
      end
    end)
  end




  defp handle_manager([data | t],project,:parameter,error)do
  {type, updated_data} = Map.pop(data,"type")
  updated_error = start_manager(updated_data,type,project,ParameterManager,nil)
  handle_manager(t,project, :parameter,updated_error)
  end

  defp handle_manager([data | t],project,:arke,error)do
    updated_error = start_manager(data,"arke",project,ArkeManager, nil)
    handle_manager(t,project, :arke,updated_error)
  end
  defp handle_manager([data | t],project,:group,error)do
    updated_error = start_manager(data,"group",project,GroupManager,Arke.System.BaseGroup)
    handle_manager(t,project, :group,updated_error)
  end

  defp handle_manager([],_project,_arke_id,error),do: error
  defp start_manager(data,type,project, manager, module,error) do
    {id, updated_data} = Map.pop(data,"id")
    case manager.create(
      Unit.new(
        String.to_atom(id),
        updated_data,
        String.to_atom(type),
        nil,
        %{},
        nil,
        nil,
        module
      ),
      project
    ) do
    %Unit{} = unit -> error
    _ -> [ Error.create(:manager, "cannot start manager for: `#{id}`")| error]
    end
  end

  defp parse([filename | t], data \\ %{}) do
     {:ok, body} = File.read!(filename)
     {:ok, json} = Jason.decode!(body)
      new_data =
        Enum.reduce(@decode_keys, %{}, fn key, acc ->
          Map.put(acc, key, Map.get(data, key, []) ++ Map.get(json, key, []))
        end)
      parse(t, new_data)
  end

  # tutti i file parsati quindi proseguire
  defp parse([], data), do: data

  defp handle_parameter([%{"id" => id, "label" => nil} = current | t], project, error),
       do: handle_parameter([Map.put(current, "label", String.capitalize(id)) | t], project, error)

  defp handle_parameter(
         [%{"id" => id, "label" => label, "type" => type} = current | t],
         project,
         error
       ) do
    with nil <- QueryManager.get_by(id: id, project: project, arke_id: type),
         %Unit{} = model <- ParameterManager.get(type, project),
         {:ok, _unit} <- QueryManager.create(project, model, current) do

      handle_parameter(t, project, error)
    else
      nil -> handle_parameter(t, project, [Error.create(:parameter, "manager does not exists for: `#{id}`") | error])
      %Unit{} -> handle_parameter(t, project, [Error.create(:parameter, "Record already exists in db for: `#{id}`") | error])
      {:error, create_error} -> handle_parameter(t, project, [create_error | error])
    end

  end

  defp handle_parameter([current | t], project, error) do
    # segnalare errore in current manca id / type
    handle_parameter(t, project, error)
  end

  defp handle_parameter([], _project, error), do: error

  defp handle_arke([%{"id" => id, "label" => nil} = current | t], project, error),
       do: handle_arke([Map.put(current, "label", String.capitalize(id)) | t], project, error)

  defp handle_arke(
         [%{"id" => id, "label" => label, "arke_id" => arke_id} = current | t],
         project,
         error
       ) do
    parameter = Map.pop(current, "parameter", [])

    with nil <- QueryManager.get_by(id: id, project: project, arke_id: arke_id),
         %Unit{} = model <- ArkeManager.get(arke_id, project),
         {:ok, unit} <- QueryManager.create(project, model, current),
         {:ok, _} <- link_parameter(parameter, unit, project) do
      handle_arke(t, project, error)

    else
      nil -> handle_arke(t, project, [Error.create(:arke, "manager does not exists for: `#{id}`") | error])
      %Unit{} -> handle_arke(t, project, [Error.create(:arke, "Record already exists in db for: `#{id}`") | error])
      {:error, create_error} -> handle_arke(t, project, [create_error | error])
    end
  end

  defp handle_arke([], project, error), do: error

  defp handle_group(
         [%{"id" => id, "label" => label} = current | t],
         project,error
       ) do
    with nil <- QueryManager.get_by(id: id, project: project, arke_id: :group),
         %Unit{} = model <- GroupManager.get(:group, project),
         {:ok, unit} <- QueryManager.create(project, model, current),
         {:ok, error} <- add_arke_to_group(unit, Map.get(current, "arke_list", []), project) do
      handle_group(t, project, error)
    else
      # non esiste manager
      nil -> {:error, nil}
      # esiste record a db
      %Unit{} -> {:error, nil}
      # errore durante la creazione, gestire di conseguenza
      _ -> {:error, nil}
    end
  end

  defp handle_link(
         [%{"type" => type, "parent" => parent, "child" => child} = current | t],
         project,
         error \\ []
       ) do
    case LinkManager.add_node(
        project,
        parent,
        child,
        type,
        Map.get(current, "metadata", %{})
      ) do

      {:ok, unit} -> handle_link(t, project, error)
      {:error, link_error}  ->
        handle_link(
          t,
          project,
          [link_error | error]
        )
    end
  end

  defp handle_link([current | t], project, error),
       do: handle_link(t, project, [Error.create(:link, "invalid parameters for #{current}}") | error])

  defp handle_link([], project, error), do: error

  defp link_parameter(p_list, arke, project) do
    param_link =
      Enum.reduce(p_list, [], fn parameter, acc ->
        [
          %{
            "child" => Map.get(parameter, "id"),
            "parent" => to_string(arke.id),
            "metadata" => Map.get(parameter, "metadata", %{}),
            "type" => "parameter"
          }
          | acc
        ]
      end)

    handle_link(param_link, project, [])
  end

  defp add_arke_to_group(arke_list, group, project) do
    group_link =
      Enum.reduce(arke_list, [], fn arke, acc ->
        [
          %{
            "parent" => to_string(group.id),
            "child" => Map.get(arke, "id"),
            "metadata" => Map.get(arke, "metadata", %{}),
            "type" => "group"
          }
          | acc
        ]
      end)

    handle_link(group_link, project, [])
  end

end