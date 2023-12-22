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
  @decode_keys [:arke, :parameter, :group, :link]
  @supported_format ["json", "yml", "yaml"]
  @shortdoc "Seed a project"
  @persistence_repo ["arke_postgres"]

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
      {[], opts}->
        Mix.Tasks.Help.run(["arke.seed_project"])
                           {opts, []} ->
      persistence = parse_persistence!(opts[:persistence] || "arke_postgres")

        app_to_start(persistence) ++ [:arke]
        |> Enum.each(&Application.ensure_all_started/1)

        repo_module = Application.get_env(:arke, :persistence)[String.to_atom(persistence)][:repo]

        case start_repo(repo_module) do
          {:ok, pid} ->

            {:ok, %{rows: rows}} = repo_module.query("SELECT * FROM information_schema.tables;")
            for [_, "public", table | _] <- rows, do:  IO.inspect(table, label: "table123")
            opts |> parse_file()
            Process.exit(pid, :normal)
            :ok

          {:error, _} ->
            {:ok, %{rows: rows}} = repo_module.query("SELECT * FROM information_schema.tables;")
            for [_, "public", table | _] <- rows, do: IO.inspect(table, label: "table123")

            opts |> parse_file()
            :ok
        end

    end

  end


  defp app_to_start("arke_postgres"), do: [:ecto_sql, :postgrex]
  defp parse_persistence!(ps) when ps in  @persistence_repo, do: ps
  defp parse_persistence!(ps), do: Mix.raise("Invalid persistence: `#{ps}`\nSupported persistence are: #{Enum.join(@persistence_repo, " | ")}")


  defp start_repo(nil), do: Mix.raise("Invalid repo module in arke configuration. Please provide a valid module accordingly to the persistence supported")
  # this is for arke_postgres
  defp start_repo(repo_module) do
    repo_module.start_link()
  end

  defp parse_file(opts)  do

    format = opts[:format] || "json"
    check_format!(format)
    all = opts[:all] || false

    # get core file to decode (arke)
    core_registry = arke_registry("arke", format)
    core_data = parse(core_registry)
    core_parameter = Map.get(core_data,:parameter, [])
    core_arke = Map.get(core_data,:arke, [])
    core_group = Map.get(core_data,:group, [])
    core_link = Map.get(core_data,:link, [])

    #get all other arke_deps registry files
    arke_deps_registry = get_arke_deps_registry(format)
    arke_deps_data = parse(arke_deps_registry)


    # todo: decidere chiave da mettere nei metadata così da identificare gli tutto ciò che viene creato e far si che da console non si possa cancellare
    # i put andranno modificati di conseguenza in modo da rendere qeusta chiave non modificabile e fissa

    file_list = Path.wildcard("./lib/registry/*.#{format}")
    raw_data = parse(file_list)
    parameter_list = core_parameter ++ Map.get(raw_data, :parameter, []) ++ Map.get(arke_deps_data, :parameter, [])
    arke_list = core_arke ++ Map.get(raw_data, :arke, []) ++ Map.get(arke_deps_data, :arke, [])
    group_list = core_group ++ Map.get(raw_data, :group, []) ++ Map.get(arke_deps_data, :group, [])
    link_list = core_link ++ Map.get(raw_data, :link, []) ++ Map.get(arke_deps_data, :link, [])

    # start core manager before create everything
    error_parameter_manager = handle_manager(core_parameter,:arke_system,:parameter)
    error_arke_manager = handle_manager(core_arke,:arke_system,:arke)
    error_group_manager = handle_manager(core_group,:arke_system,:group)

    input_project = String.to_atom(opts[:project]) || :arke_system

    project_list = get_project(input_project, all)

    write_data(input_project,project_list,core_data,parameter_list,arke_list,group_list,link_list)

  end

  defp write_data(input_project,project_list,_core_data,_parameter_list,_arke_list,_group_list,_link_list) when length(project_list) == 0, do: Mix.raise("No project found for `#{Enum.join(input_project, " | ")}`")

  defp write_data(input_project,project_list,core_data,parameter_list,arke_list,group_list,link_list)  do
    Enum.each(project_list, fn project ->
      unless to_string(project) == "arke_system" do
        error_parameter_manager = handle_manager(Map.get(core_data,:parameter, []),project,:parameter)
        error_arke_manager = handle_manager(Map.get(core_data,:arke, []),project,:arke)
        error_group_manager = handle_manager(Map.get(core_data,:group, []),project,:group)
      end
      IO.inspect("start parameter")
      error_parameter = handle_parameter(parameter_list, project,[])
      IO.inspect("end parameter")
      IO.inspect("start arke")
      error_arke = handle_arke(arke_list, project,[])
      IO.inspect("end arke")
      IO.inspect("start group")
      error_group = handle_group(group_list, project,[])
      IO.inspect("end group")
      IO.inspect("start link")
      error_link = handle_link(link_list, project,[])
      IO.inspect("end link")

      IO.inspect(error_parameter, label: "error_parameter123")
      IO.inspect(error_arke, label: "error_arke123")
      IO.inspect(error_group, label: "error_group123")
      IO.inspect(error_link, label: "error_link123")
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

  defp get_project(_input_project, true) do
    QueryManager.filter_by(arke_id: :arke_project, project: :arke_system)
    |> Enum.map( fn unit -> to_string(unit.id) end)
  end

  defp get_project(input_project, _all), do: [input_project]


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

  defp handle_manager(_data,_project,_arke_id,error\\[])
  defp handle_manager([data | t],project,:parameter,error)do
  {type, updated_data} = Map.pop(data,:type)
  updated_error = start_manager(updated_data,type,project,ParameterManager,nil)
  handle_manager(t,project, :parameter,updated_error)
  end

  defp handle_manager([data | t],project,:arke,error) do
    {flatten_data,other} = Map.pop(data,:data,%{})
    updated_data = Map.merge(flatten_data,other)
                   |> Map.put(:type,"arke")
                   |> Map.put_new(:active,true)
    final_data = Map.replace(updated_data,:parameters,parse_arke_parameter(updated_data,project))
    module = get_module(final_data)
    updated_error = start_manager(final_data,"arke",project,ArkeManager, module)
    handle_manager(t,project, :arke,updated_error)
  end
  defp handle_manager([data | t],project,:group,error)do

    updated_error = start_manager(Map.put_new(data,:metadata,%{}),"group",project,GroupManager,Arke.System.BaseGroup)
    handle_manager(t,project, :group,updated_error)
  end

  defp handle_manager([],_project,_arke_id,error),do: error
  defp start_manager(_data,_type,_project, _manager, _module,error\\[])

  defp start_manager(data,type,project, manager, module,error) do
    case Map.pop(data,:id,nil) do
      {nil, _updated_data} -> [Error.create(:manager, "key id not found")| error]
      {id, updated_data} ->  case manager.create(
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
                               %Unit{} = unit ->
                                 IO.inspect(unit, label: "manager1234")
                                 error
                               _ -> [Error.create(:manager, "cannot start manager for: `#{id}`")| error]
                             end
    end

  end

  defp parse(file_list,file_data \\ %{})
  defp parse([filename | t], data) do
    try do
     body = File.read!(filename)
     json = Jason.decode!(body, keys: :atoms)
      new_data =
        Enum.reduce(@decode_keys, %{}, fn key, acc ->
          Map.put(acc, key, Map.get(data, key, []) ++ Map.get(json, key, []))
        end)
      parse(t, new_data)
    rescue
    err in Jason.DecodeError ->

   %{data: data, token: token, position: position} = err
      Mix.raise("Json error in: #{filename}.\n Position: #{position}\n token: #{token}\n data: #{data}")
    err in File.Error ->
      %{reason: reason}= err
      Mix.raise("Error open file: #{filename}. \n Reason: #{reason}")
    end
  end

  # tutti i file parsati quindi proseguire
  defp parse([], data), do: data


  defp handle_parameter([%{id: id, label:  nil} = current | t], project, error),
       do: handle_parameter([Map.put(current, :label, String.capitalize(id)) | t], project, error)

  defp handle_parameter(
         [%{id: id, label: label, type:  type} = current | t],
         project,
         error
       ) do
    try do
    with nil <- QueryManager.get_by(id: id, project: project, arke_id: type),
         %Unit{} = model <- ArkeManager.get(String.to_atom(type), project),
         {:ok, _unit} <- QueryManager.create(project, model, current) do

      handle_parameter(t, project, error)
    else
      nil ->  handle_parameter(t, project, [Error.create(:parameter, "manager does not exists for: `#{id}`") | error])
      %Unit{} -> handle_parameter(t, project, [Error.create(:parameter, "Record already exists in db for: `#{id}`") | error])
      {:error, create_error} -> handle_parameter(t, project, [create_error | error])
        err -> IO.inspect(err,label: "quarto error")
    end
    rescue
      _ ->  handle_parameter(t, project, [Error.create(:parameter, "Something went wrong for: `#{id}`") | error])
    end

  end

  defp handle_parameter([current | t], project, error) do
    handle_parameter(t, project, [Error.create(:parameter, "Missing parameter `id` or `type`") | error])
  end

  defp handle_parameter([], _project, error), do: error

  defp handle_arke([%{id: id, label: nil} = current | t], project, error),
       do: handle_arke([Map.put(current, "label", String.capitalize(id)) | t], project, error)

  defp handle_arke(
         [%{id: id, label: label} = current | t],
         project,
         error
       ) do
    parameter = Map.pop(current, :parameter, [])
    #aggiungere try do block
    with nil <- QueryManager.get_by(id: id, project: project, arke_id: "arke"),
         %Unit{} = model <- ArkeManager.get(String.to_atom(id), project),
         {:ok, unit} <- QueryManager.create(project, model, current),
         {:ok, _} <- link_parameter(parameter, unit, project) do
      handle_arke(t, project, error)

    else
      nil -> IO.inspect("primo errore arke")
        handle_arke(t, project, [Error.create(:arke, "manager does not exists for: `#{id}`") | error])
      %Unit{} -> IO.inspect("secondo errore arke")
                 handle_arke(t, project, [Error.create(:arke, "Record already exists in db for: `#{id}`") | error])
      {:error, create_error} -> IO.inspect("terzp errore arke")
                                handle_arke(t, project, [create_error | error])
    end
  end

  defp handle_arke([], project, error), do: error

  defp handle_group(
         [%{id: id, label: label} = current | t],
         project,error
       ) do
    with nil <- QueryManager.get_by(id: id, project: project, arke_id: :group),
         %Unit{} = model <- GroupManager.get(:group, project),
         {:ok, unit} <- QueryManager.create(project, model, current),
         {:ok, error} <- add_arke_to_group(unit, Map.get(current, :arke_list, []), project) do
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

  defp handle_group([], project, error), do: error
  defp handle_link(data,project, error \\ [])
  defp handle_link(
         [%{type: type, parent: parent, child: child} = current | t],
         project,
         error
       ) do
    case LinkManager.add_node(
        project,
        parent,
        child,
        type,
        Map.get(current, :metadata, %{})
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
            "child" => Map.get(parameter, :id),
            "parent" => to_string(arke.id),
            "metadata" => Map.get(parameter, :metadata, %{}),
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
            "child" => to_string(Map.get(arke, :id)),
            "metadata" => Map.get(arke, :metadata, %{}),
            "type" => "group"
          }
          | acc
        ]
      end)

    handle_link(group_link, project, [])
  end

  defp parse_arke_parameter(data,project) do

   Map.get(data,:parameters) |> Enum.reduce([], fn param,acc ->
    # todo: fare controllo per cui se esce tbd (sarà poi nil) scrivere sul file che la chiave manca
      converted = Map.update(param,:id, "tbd", &String.to_atom(&1))
      id = converted[:id]
      arke = ParameterManager.get(id,project)
     [ Map.put(converted,:arke, arke.arke_id) | acc]
     end)
  end


  defp get_module(data) do
    # get all the arke modules which has the arke macro defined
    # find the right module for the given data and return it
    arke_module_list = Enum.reduce(:application.loaded_applications(), [], fn {app, _, _}, arke_list ->
      {:ok, modules} = :application.get_key(app, :modules)

      module_arke_list =
        Enum.reduce(modules, [], fn mod, mod_arke_list ->
          is_arke =
            Code.ensure_loaded?(mod) and :erlang.function_exported(mod, :arke_from_attr, 0) and
            mod.arke_from_attr != nil
            if is_arke do
              [%{module: mod, arke_id: mod.arke_from_attr().id} | mod_arke_list]
              else
            mod_arke_list
            end
        end)


      arke_list ++ module_arke_list
    end)
    Enum.find(arke_module_list,%{module: nil, arke_id: nil}, fn %{module: module, arke_id: arke_id} -> arke_id == String.to_atom(Map.get(data,:id)) end)[:module]
  end

end