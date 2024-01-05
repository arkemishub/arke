# Copyright 2023 Arkemis S.r.l.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
defmodule Mix.Tasks.Arke.CreateMember do
  alias Arke.QueryManager
  alias Arke.Boundary.{ArkeManager, GroupManager}
  alias Arke.Core.Unit
  use Mix.Task

  @shortdoc "Creates a new member"

  @moduledoc """
  Creates a new  super_admin member for the given project.
  If no username/password are provided then a default member admin/admin will be created if no other admin exists
  ## Examples
      $ mix arke.create_member --project my_project --username my_username --password mypassword
  ## Options
    * `--project` - The id of the project where to create the member
    * `--username` - The username of the member
    * `--password` - The password of the member
    * `--persistence` - Persistence used to create the member

  """
  @persistence_repo ["arke_postgres"]
  @switches [
    project: :string,
    username: :string,
    password: :string,
  ]


  @impl true
  def run(args) do

    case OptionParser.parse!(args, strict: @switches) do
      {[], _opts}->
        Mix.Tasks.Help.run(["arke.create_member"])
      {opts, []} ->
        persistence = parse_persistence!(opts[:persistence] || "arke_postgres")

        app_to_start(persistence) ++ [:arke]
        |> Enum.each(&Application.ensure_all_started/1)

        repo_module = Application.get_env(:arke, :persistence)[String.to_atom(persistence)][:repo]

        case start_repo(repo_module) do
          {:ok, pid} ->
            opts |> create_member()
            Process.exit(pid, :normal)
            :ok

          {:error, _} ->
            opts |> create_member()
            :ok
        end

    end

  end


  defp app_to_start("arke_postgres"), do: [:ecto_sql, :postgrex,:arke_postgres]
  defp parse_persistence!(ps) when ps in  @persistence_repo, do: ps
  defp parse_persistence!(ps), do: Mix.raise("Invalid persistence: `#{ps}`\nSupported persistence are: #{Enum.join(@persistence_repo, " | ")}")

  defp start_repo(nil), do: Mix.raise("Invalid repo module in arke configuration. Please provide a valid module accordingly to the persistence supported")
  # this is for arke_postgres
  defp start_repo(repo_module) do
    repo_module.start_link()
  end

  defp create_member(opts) do
    project = check_data!(opts[:project],"`project` not found. Please provide one.")
    password = check_data!(opts[:password],"`password` can not be empty")
    username = check_data!(opts[:username],"`username` can not be empty")

      case GroupManager.get(:arke_auth_member, String.to_atom(project)) do
        %Unit{} ->
          create_user(username,password,project)
          _ -> Mix.raise("`arke_auth_member` manager not found. Please init the database before.")
      end

    end

  defp check_data!(nil,msg), do: Mix.raise(msg)
  defp check_data!(data,_msg), do: data
  defp create_user(username, password,project) when is_binary(project) , do: create_user(username, password,String.to_atom(project))
  defp create_user(username, password,project) do
    user_model = ArkeManager.get(:user,project)
    user_data = %{username: username,password: password, email: "#{username}@foo.test"}
    case QueryManager.create(project,user_model,user_data) do
    {:ok,%Unit{id: id}} ->
             case  QueryManager.get_by(project: project, arke_id: :super_admin, arke_system_user: id) do
               nil ->

                 member_model = ArkeManager.get(:super_admin,project)
                 case QueryManager.create(project,member_model, arke_system_user: id) do
                   {:ok,%Unit{}} -> IO.puts("#{IO.ANSI.green()}--- member #{username} created ---#{IO.ANSI.reset()}")
                  _ ->  Mix.raise("Can not create member with given data")
                 end
               _ ->
                 IO.inspect("member already exists",syntax_colors: [string: :red])
             end
    {:error,[%{context: "parameter_validation", message: msg}]}-> Mix.raise(msg)
    _ ->
      Mix.raise("Can not create member with given data")
    end
    end
end

