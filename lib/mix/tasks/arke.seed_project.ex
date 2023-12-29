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
  #  parameter.json
  # add to:  arke_list,default_link {
  ##          "id": "filter_keys",
  ##          "metadata": {
  ##               "default_string": ["id","arke_id"]
  ##          }
  ##        },
  #  add to:  arke_or_group_id {
  ##          "id": "filter_keys",
  ##          "metadata": {
  ##               "default_string": ["id","label"]
  ##          }
  ##        },

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
      {[], _opts}->
        Mix.Tasks.Help.run(["arke.seed_project"])
                           {opts, []} ->
      persistence = parse_persistence!(opts[:persistence] || "arke_postgres")

        app_to_start(persistence) ++ [:arke]
        |> Enum.each(&Application.ensure_all_started/1)

        repo_module = Application.get_env(:arke, :persistence)[String.to_atom(persistence)][:repo]

        case start_repo(repo_module) do
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


  defp app_to_start("arke_postgres"), do: [:ecto_sql, :postgrex]
  defp parse_persistence!(ps) when ps in  @persistence_repo, do: ps
  defp parse_persistence!(ps), do: Mix.raise("Invalid persistence: `#{ps}`\nSupported persistence are: #{Enum.join(@persistence_repo, " | ")}")

  defp check_file(_arke_id, []), do: nil
  defp check_file(arke_id, data) do
    {:ok, datetime} = Arke.DatetimeHandler.now(:datetime) |> Arke.DatetimeHandler.format("{ISO:Basic:Z}")
    dir_path = "log/arke_seed_project"
    path = "#{dir_path}/#{datetime}_#{to_string(arke_id)}.log"

    File.mkdir("log")

    case File.exists?(dir_path) do
      true ->
        write_log_to_file(path, data)

      false ->
        File.mkdir!(dir_path)
        write_log_to_file(path, data)
    end
  end

  defp write_log_to_file(path, data) do
    {:ok, body} = Jason.encode(data)
    {:ok, file} = File.open(path, [:append])
    IO.write(file, body)
    File.close(file)
  end

  defp start_repo(nil), do: Mix.raise("Invalid repo module in arke configuration. Please provide a valid module accordingly to the persistence supported")
  # this is for arke_postgres
  defp start_repo(repo_module) do
    repo_module.start_link()
  end

  defp parse_file(opts)  do

    format = opts[:format] || "json"
    check_format!(format)
    all = opts[:all] || false

    # get core file to decode (arke) and append all other arke_deps registry files
    core_registry = arke_registry("arke", format)
    core_data = parse(core_registry)

    arke_deps_registry = get_arke_deps_registry(format)
    arke_deps_data = parse(arke_deps_registry)
    core_parameter = Map.get(core_data,:parameter, []) ++ Map.get(arke_deps_data, :parameter, [])
    core_arke = Map.get(core_data,:arke, []) ++ Map.get(arke_deps_data, :arke, [])
    core_group = Map.get(core_data,:group, []) ++ Map.get(arke_deps_data, :group, [])
    core_link = Map.get(core_data,:link, []) ++ Map.get(arke_deps_data, :link, [])



    # todo: decidere chiave da mettere nei metadata così da identificare gli tutto ciò che viene creato e far si che da console non si possa cancellare
    # i put andranno modificati di conseguenza in modo da rendere qeusta chiave non modificabile e fissa
    # aggiungere blocchi try do rescue nei vari handle_parameter/arke/group/link e scrivere nei vari file

    file_list = Path.wildcard("./lib/registry/*.#{format}")
    raw_data = parse(file_list)
    parameter_list = core_parameter ++ Map.get(raw_data, :parameter, [])
    arke_list = core_arke ++ Map.get(raw_data, :arke, [])
    group_list = core_group ++ Map.get(raw_data, :group, [])
    link_list = core_link ++ Map.get(raw_data, :link, [])

    # start core manager before create everything
    error_parameter_manager = handle_manager(core_parameter,:arke_system,:parameter)
    error_arke_manager = handle_manager(core_arke,:arke_system,:arke)
    error_group_manager = handle_manager(core_group,:arke_system,:group)

    check_file("system_parameter_manager",error_parameter_manager)
    check_file("system_arke_manager",error_arke_manager)
    check_file("system_group_manager",error_group_manager)

    input_project = String.to_atom(opts[:project]) || :arke_system

    project_list = get_project(input_project, all)

    write_data(input_project,project_list,core_data,parameter_list,arke_list,group_list,link_list)

  end

  defp write_data(input_project,project_list,_core_data,_parameter_list,_arke_list,_group_list,_link_list) when length(project_list) == 0, do: Mix.raise("No project found for `#{Enum.join(input_project, " | ")}`")

  defp write_data(_input_project,project_list,core_data,parameter_list,arke_list,group_list,link_list)  do
    Enum.each(project_list, fn project ->
      unless to_string(project) == "arke_system" do
        error_parameter_manager = handle_manager(Map.get(core_data,:parameter, []),project,:parameter)
        error_arke_manager = handle_manager(Map.get(core_data,:arke, []),project,:arke)
        error_group_manager = handle_manager(Map.get(core_data,:group, []),project,:group)
        check_file("#{project}_parameter_manager",error_parameter_manager)
        check_file("#{project}_arke_manager",error_arke_manager)
        check_file("#{project}_group_manager",error_group_manager)
      end
      error_parameter = handle_parameter(parameter_list, project,[])
      error_arke = handle_arke(arke_list, project,[])
      error_group = handle_group(group_list, project,[])
      error_link = handle_link(link_list, project,[])


      check_file("parameter",error_parameter)
      check_file("arke",error_arke)
      check_file("group",error_group)
      check_file("link",error_link)

    end)
    end
  defp arke_registry(package_name,format) do
    # Get arke's dependecies based on the env path.
    env_var = System.get_env()
    case Enum.find(env_var,fn  {k,_v}-> String.contains?(String.downcase(k), "ex_dep_#{package_name}_path") end) do
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

  defp handle_manager(_data,_project,_arke_id,_error\\[])
  defp handle_manager([data | t],project,:parameter,error)do
  {type, updated_data} = Map.pop(data,:type)
  updated_error = start_manager(updated_data,type,project,ParameterManager,nil)
  handle_manager(t,project, :parameter,updated_error ++ error)
  end

  defp handle_manager([data | t],project,:arke,error) do
    {flatten_data,other} = Map.pop(data,:data,%{})
    updated_data = Map.merge(flatten_data,other)
                   |> Map.put(:type,Map.get(data,:type,"arke"))
                   |> Map.put_new(:active,true)
    final_data = Map.replace(updated_data,:parameters,parse_arke_parameter(updated_data,project))
    module = get_module(final_data, "arke")
    updated_error = start_manager(final_data,"arke",project,ArkeManager, module)
    handle_manager(t,project, :arke,updated_error ++ error)
  end
  defp handle_manager([data | t],project,:group,error)do
    #todo: check if in arke_list we need also metadata besides the id
    loaded_list = Enum.reduce(Map.get(data,:arke_list,[]),[], fn id,acc ->
      case Arke.Boundary.ArkeManager.get(id, project) do
        {:error, _msg} ->
          [create_error("arke_list_group","no manager has been found for: `#{id}` in `#{project}`") | error]
        arke ->
          [arke | acc]
      end

    end)
    final_data= Map.put_new(data,:metadata,%{})
                |> Map.put(:arke_list,loaded_list)
    module = get_module(final_data, "group")
    updated_error = start_manager(final_data,"group",project,GroupManager,module)
    handle_manager(t,project, :group,updated_error ++ error)
  end

  defp handle_manager([],_project,_arke_id,error),do: error
  defp start_manager(_data,_type,_project, _manager, _module,_error\\[])

  defp start_manager(data,type,project, manager, module,error) do
    case Map.pop(data,:id,nil) do
      {nil, _updated_data} -> parse_error(create_error(:manager, "key id not found"), error)
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
                               %Unit{} = _unit ->
                                 error
                               _ -> parse_error(create_error(:manager, "cannot start manager for: `#{id}`"), error)
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
         [%{id: id, type:  type} = current | t],
         project,
         error
       ) do

    with nil <- QueryManager.get_by(id: id, project: project, arke_id: type),
         %Unit{} = model <- ArkeManager.get(String.to_atom(type), project),
         {:ok, _unit} <- QueryManager.create(project, model, current) do

      handle_parameter(t, project, error)
    else
      nil ->  handle_parameter(t, project, parse_error(create_error(:parameter, "manager does not exists for: `#{id}`") , error))
      %Unit{} -> handle_parameter(t, project, parse_error(create_error(:parameter, "Record already exists in db for: `#{id}`") , error))
      {:error, err} ->
        handle_parameter(t, project, parse_error(err, error))
        _err ->
               handle_parameter(t, project, parse_error(create_error(:parameter, "Something went wrong for: `#{id}`") ,error))
    end


  end

  defp handle_parameter([_current | t], project, error) do
    handle_parameter(t, project, parse_error(create_error(:parameter, "Missing parameter `id` or `type`") , error))
  end

  defp handle_parameter([], _project, error), do: error

  defp handle_arke([%{id: id, label: nil} = current | t], project, error),
       do: handle_arke([Map.put(current, "label", String.capitalize(id)) | t], project, error)

  defp handle_arke(
         [%{id: id} = current | t],
         project,
         error
       ) do
    {parameter,new_data} = Map.pop(current, :parameters, [])

    #aggiungere try do block
    with nil <- QueryManager.get_by(id: id, project: project, arke_id: "arke"),
         %Unit{} = model <- ArkeManager.get(:arke, project),
         {:ok, unit} <- QueryManager.create(project, model, new_data),
         link_parameter_error <- link_parameter(parameter, unit, project) do
      if length(link_parameter_error) == 0 do
        handle_arke(t, project,  error)
        else
        handle_arke(t, project,  [%{"parameter_error_#{id}": link_parameter_error}|error])
      end

    else
      nil ->
        handle_arke(t, project, parse_error(create_error(:arke, "manager does not exists for: `#{id}`"), error))
      %Unit{}=_unit ->
                 handle_arke(t, project, parse_error(create_error(:arke, "Record already exists in db for: `#{id}`") , error))
      {:error, err} ->
                                handle_arke(t, project, [err | error])
    end
  end

  defp handle_arke([], _project, error), do: error

  defp handle_group(
         [%{id: id} = current | t],
         project,error
       ) do
    with nil <- QueryManager.get_by(id: id, project: project, arke_id: :group),
         %Unit{} = model <- ArkeManager.get(:group, project),
         {:ok, unit} <- QueryManager.create(project, model, current),
         error_group <- add_arke_to_group(unit, project) do
      handle_group(t, project, error ++ error_group)
    else
      nil ->
             handle_group(t, project, parse_error(create_error(:arke, "manager does not exists for: `#{id}`"), error))
      %Unit{}=_unit ->
                      handle_group(t, project, parse_error(create_error(:arke, "Record already exists in db for: `#{id}`"),error))
      {:error, err} ->
                                handle_group(t, project, [err | error])
    end
  end

  defp handle_group([], _project, error), do: error
  defp handle_link(_data,_project, _error \\ [])
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

      {:ok, _unit} -> handle_link(t, project, error)
      {:error, link_error}  ->
        handle_link(
          t,
          project,
          [link_error | error]
        )
    end
  end

  defp handle_link([current | t], project, error),
       do: handle_link(t, project, parse_error(create_error(:link, "invalid parameters for #{current}}"),error))

  defp handle_link([], _project, error), do: error

  defp link_parameter(p_list, arke, project) do
    param_link =
      Enum.reduce(p_list, [], fn parameter, acc ->
        [
          %{
            child: Map.get(parameter, :id),
            parent: to_string(arke.id),
            metadata: Map.get(parameter, :metadata, %{}),
            type: "parameter"
          }
          | acc
        ]
      end)

    handle_link(param_link, project, [])
  end

  defp add_arke_to_group(group, project) do
    arke_list = Map.get(group, :arke_list, [])
    group_link =
      Enum.reduce(arke_list, [], fn arke, acc ->
        [
          %{
            parent: to_string(group.id),
            child: to_string(Map.get(arke, :id)),
            metadata: Map.get(arke, :metadata, %{}),
            type: "group"
          }
          | acc
        ]
      end)

    handle_link(group_link, project, [])
  end

  defp parse_arke_parameter(data,project) do

   Map.get(data,:parameters) |> Enum.reduce([], fn param,acc ->
    # todo: fare controllo per cui se esce tbd (sarà poi nil) scrivere sul file che la chiave  id manca
      converted = Map.update(param,:id, "tbd", &String.to_atom(&1))
      id = converted[:id]
      arke = ParameterManager.get(id,project)
     [ Map.put(converted,:arke, arke.arke_id) | acc]
     end)
  end


  defp get_module(data,type) do
    # get all the arke modules which has the arke macro defined
    # find the right module for the given data and return it
    arke_module_list = Enum.reduce(:application.loaded_applications(), [], fn {app, _, _}, arke_list ->
      {:ok, modules} = :application.get_key(app, :modules)

      function_name = get_module_fn(type)

      module_arke_list =
        Enum.reduce(modules, [], fn mod, mod_arke_list ->
            if Code.ensure_loaded?(mod) and :erlang.function_exported(mod, function_name, 0) and
               apply(mod, function_name,[]) != nil do
              [%{module: mod, arke_id: apply(mod, function_name,[]).id} | mod_arke_list]
              else
              mod_arke_list
            end
        end)


      arke_list ++ module_arke_list
    end)
    Enum.find(arke_module_list,%{module: nil, arke_id: nil}, fn %{module: _module, arke_id: arke_id} -> arke_id == String.to_atom(Map.get(data,:id)) end)[:module]
  end
  defp get_module_fn("arke"), do: :arke_from_attr
  defp get_module_fn("group"), do: :group_from_attr

  defp create_error(context,msg) do
    {:error,msg} = Error.create(context,msg)
    msg
  end

  defp parse_error(error_message, error_accumulator) when is_list(error_message), do: error_message ++error_accumulator
  defp parse_error(error_message, error_accumulator), do: [error_message | error_accumulator]
end