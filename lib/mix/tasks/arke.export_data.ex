defmodule Mix.Tasks.Arke.ExportData do
  @moduledoc """
  Export data from a given project in the database and save them in json file.

  ## Examples

      $ mix arke.export_data --project my_project1 --p myproject2
      $ mix arke.export_data --project my_project --all
      $ mix arke.export_data --project my_project --arke

  ## Command line options

  * `--project` - The id of the project used to export data.
  * `--all` - Export all arkes,groups and parameters
  * `--arke` - Export only the arkes
  * `--group` - Export only the groups
  * `--parameter` - Export only the parameters
  * `--split_file` - Write different files for arkes,groups,parameters and links
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
  @shortdoc "Export data from a project"
  @persistence_repo ["arke_postgres"]

  @switches [
    project: :string,
    all: :boolean,
    arke: :boolean,
    parameter: :boolean,
    split_file: :boolean,
    group: :boolean,
    persistence: :string,
  ]
  @aliases [
    p: :project,
    A: :all,
    a: :arke,
    g: :group,
    sf: :split_file,
    pr: :parameter,
    ps: :persistence,
  ]

  @impl true
  def run(args) do

    case OptionParser.parse!(args, strict: @switches, aliases: @aliases) do
      {[], _opts}->
        Mix.Tasks.Help.run(["arke.export_data"])
      {opts, []} ->
        persistence = parse_persistence!(opts[:persistence] || "arke_postgres")

        app_to_start(persistence) ++ [:arke]
        |> Enum.each(&Application.ensure_all_started/1)

        repo_module = Application.get_env(:arke, :persistence)[String.to_atom(persistence)][:repo]
        Mix.shell().info("--- Starting repo --- ")
        case start_repo!(repo_module) do
          {:ok, pid} ->

            opts |> export_data(persistence)
            Process.exit(pid, :normal)
            :ok

          {:error, _} ->
            opts |> export_data(persistence)
            :ok
        end

    end

  end


  defp app_to_start("arke_postgres"), do: [:ecto_sql, :postgrex]
  defp parse_persistence!(ps) when ps in  @persistence_repo, do: ps
  defp parse_persistence!(ps), do: Mix.raise("Invalid persistence: `#{ps}`\nSupported persistence are: #{Enum.join(@persistence_repo, " | ")}")

  defp write_to_file(project,arke_id,data) do
    {:ok, datetime} = Arke.Utils.DatetimeHandler.now(:datetime) |> Arke.Utils.DatetimeHandler.format("{ISO:Basic:Z}")
    dir_path = "export/arke_export_data/#{project}/#{datetime}"
    arke_id_str = to_string(arke_id)
    path = "#{dir_path}/#{arke_id_str}.json"
    Mix.shell().info("--- Writing data to #{path} for #{arke_id_str}  --- ")

    File.mkdir_p!(dir_path)
    {:ok, body} = Jason.encode(data)
    {:ok, file} = File.open(path, [:append])
    IO.write(file, body)
    File.close(file)

  end


  defp start_repo!(nil), do: Mix.raise("Invalid repo module in arke configuration. Please provide a valid module accordingly to the persistence supported")
  # this is for arke_postgres
  defp start_repo!(repo_module) do
    repo_module.start_link()
  end

  defp start_manager!(nil), do: Mix.raise("Missing `start_manager` function in arke.persistence configuration. Please provide a valid function accordingly to the persistence supported")
  # this is for arke_postgres
  defp start_manager!(function), do: function.()


  defp export_data(opts,persistence)  do
    start_manager!(Application.get_env(:arke, :persistence)[String.to_atom(persistence)][:start_manager])
    project = String.to_atom(opts[:project]) || :arke_system
    split_file =  opts[:split_file] || false
    data = get_data(project,opts)
    arke = prepare_arke(data.arke,data.arke_parameter)
    group = prepare_group(data.group)
    parameter = prepare_parameter(data.parameter)
    permission = prepare_permission(data.permission)

    if opts[:split_file] do
      write_to_file(project,:arke,%{arke: arke})
      write_to_file(project,:group,%{group: group})
      write_to_file(project,:parameter,%{parameter: parameter})
      write_to_file(project,:link,%{link: permission})
    else
      write_to_file(project,:all,%{arke: arke,group: group,parameter: parameter,link: permission})
    end

    Mix.shell().info("--- All data has been exported. Keep in mind that if you want to use them in the `arke.seed_project` task
       you must move them under the `registry` folder --- ")
  end

  def get_data(project,opts) do
    all = opts[:all] || false
      if all do
        get_all(project)
      else
        arke =  get_arke(project,opts[:arke])
        arke_parameter =  get_arke_parameter(project)
        parameter =  get_parameter(project,opts[:parameter])
        group =  get_group(project,opts[:group])
        permission = get_permission(project)
        %{arke: arke, parameter: parameter, group: group, permission: permission, arke_parameter: arke_parameter}
      end
  end

  defp get_arke(project, nil), do: []
  defp get_arke(project,_), do: QueryManager.filter_by(project: project, arke_id: "arke")

  defp get_parameter(project,nil), do: []
  defp get_parameter(project,_), do: QueryManager.filter_by(project: project, arke_id__in: Arke.Utils.DefaultData.get_parameters_id())

  defp get_group(project,nil), do: []
  defp get_group(project,_), do: QueryManager.filter_by(project: project, arke_id: "group")

  defp get_permission(project) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)
    QueryManager.query(project: project, arke: arke_link.id)
    |> QueryManager.where(type: "permission")
    |> QueryManager.all
  end

  defp get_arke_parameter(project) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)
    QueryManager.query(project: project, arke: arke_link.id)
    |> QueryManager.where(type: "parameter")
    |> QueryManager.all
  end

  defp get_all(project) do
    data = QueryManager.filter_by(project: project, arke_id__in: Arke.Utils.DefaultData.get_arke_id())
    p_list = Arke.Utils.DefaultData.get_parameters_id()
    parsed_data = Enum.reduce(data,%{arke: [],group: [],parameter: []}, fn unit,acc ->
    parse_data(unit,to_string(unit.arke_id),p_list,acc)
    end)
    Map.put(parsed_data,:permission, get_permission(project))
    |>Map.put(:arke_parameter, get_arke_parameter(project))
  end

  defp parse_data(unit,"arke",_p_list,acc), do: %{acc | arke: acc.arke ++ [unit]}
  defp parse_data(unit,"group",_p_list,acc), do: %{acc | group: acc.group ++ [unit]}
  defp parse_data(unit,arke_id,p_list,acc) do
    if arke_id in p_list do
      %{acc | parameter: acc.parameter ++ [unit]}
    else
      acc
    end
  end

  # parse arke and make them usable for seed_project
  defp prepare_arke(data,arke_param_list) do
    Enum.map(data,fn arke ->
    parameters = Enum.filter(arke_param_list, fn p -> to_string(p.data.parent_id) == to_string(arke.id) end)
    |> Enum.map(fn p -> %{id: to_string(p.data.child_id), metadata: Map.delete(p.metadata,:project)} end)
    %{id: to_string(arke.id),label: arke.data.label, parameters: parameters}
    end)
  end

  defp prepare_group(data) do
    Enum.map(data,fn group ->
      %{id: to_string(group.id),label: group.data.label, description: group.data.description,arke_list: group.data.arke_list}
    end)
  end

  defp prepare_parameter(data), do: Enum.map(data,fn parameter-> Map.put(parameter.data,:id,to_string(parameter.id))end)

  defp prepare_permission(data), do: Enum.map(data, fn permission ->
    Map.get(permission.data) |> Map.put(:metadata,Map.delete(permission.metadata,:project)) end)

end