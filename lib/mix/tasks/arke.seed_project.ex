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
  alias Arke.Boundary.{ArkeManager}

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
    core_data = parse(core_registry,format)

    arke_deps_registry = get_arke_deps_registry(format)
    arke_deps_data = parse(arke_deps_registry,format)
    core_parameter = Map.get(core_data,:parameter, []) ++ Map.get(arke_deps_data, :parameter, [])
    core_arke = Map.get(core_data,:arke, []) ++ Map.get(arke_deps_data, :arke, [])
    core_group = Map.get(core_data,:group, []) ++ Map.get(arke_deps_data, :group, [])
    core_link = Map.get(core_data,:link, []) ++ Map.get(arke_deps_data, :link, [])



    # todo: decidere chiave da mettere nei metadata così da identificare gli tutto ciò che viene creato e far si che da console non si possa cancellare
    # i put andranno modificati di conseguenza in modo da rendere qeusta chiave non modificabile e fissa
    # aggiungere blocchi try do rescue nei vari handle_parameter/arke/group/link e scrivere nei vari file

    file_list = Path.wildcard("./lib/registry/*.#{format}")
    raw_data = parse(file_list,format)
    parameter_list = core_parameter ++ Map.get(raw_data, :parameter, [])
    arke_list = core_arke ++ Map.get(raw_data, :arke, [])
    group_list = core_group ++ Map.get(raw_data, :group, [])
    link_list = core_link ++ Map.get(raw_data, :link, [])

    # start core manager before create everything
    error_parameter_manager = Arke.handle_manager(core_parameter,:arke_system,:parameter)
    error_arke_manager = Arke.handle_manager(core_arke,:arke_system,:arke)
    error_group_manager = Arke.handle_manager(core_group,:arke_system,:group)

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
        error_parameter_manager = Arke.handle_manager(Map.get(core_data,:parameter, []),project,:parameter)
        error_arke_manager = Arke.handle_manager(Map.get(core_data,:arke, []),project,:arke)
        error_group_manager = Arke.handle_manager(Map.get(core_data,:group, []),project,:group)
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


  defp parse(file_list,format,file_data \\ %{})
  defp parse([filename | t],"json"=format, data) do
    try do
     body = File.read!(filename)
     json = Jason.decode!(body, keys: :atoms)
      new_data =
        Enum.reduce(@decode_keys, %{}, fn key, acc ->
          Map.put(acc, key, Map.get(data, key, []) ++ Map.get(json, key, []))
        end)
      parse(t, format,new_data)
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
  defp parse([],format, data), do: data


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
        handle_parameter(t, project, parse_error(err, error,id))
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
        handle_arke(t, project,  [%{"#{id}_parameter_association": link_parameter_error}|error])
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

  defp handle_link([current | t], project, error),do:
       handle_link(t, project, parse_error(create_error(:link, "invalid parameters for #{current}}"),error))

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


  defp create_error(context,msg) do
    {:error,msg} = Error.create(context,msg)
    msg
  end

  defp parse_error(error_message, error_accumulator) when is_list(error_message), do: error_message ++error_accumulator
  defp parse_error(error_message, error_accumulator), do: [error_message | error_accumulator]
  defp parse_error(error_message, error_accumulator,id), do: [%{create: id, error: error_message} | error_accumulator]
end