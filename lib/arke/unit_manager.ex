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

defmodule Arke.UnitManager do
  defmacro __using__(_) do
    quote do
      use GenServer
      alias Arke.Core.Unit
      alias Arke.Utils.ErrorGenerator, as: Error

      #      @after_compile __MODULE__
      Module.register_attribute(__MODULE__, :registry_name, accumulate: false, persist: true)
      Module.register_attribute(__MODULE__, :supervisor_name, accumulate: false, persist: true)

      Module.register_attribute(__MODULE__, :arke_list, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :group_list, accumulate: true, persist: false)

      import unquote(__MODULE__), only: [set_registry_name: 1, set_supervisor_name: 1]

      #            @before_compile unquote(__MODULE__)

      def arke_list(), do: Keyword.get(__MODULE__.__info__(:attributes), :arke_list, [])
      def group_list(), do: Keyword.get(__MODULE__.__info__(:attributes), :arke_list, [])

      def registry_name,
        do: Keyword.get(__MODULE__.__info__(:attributes), :registry_name, []) |> List.first()

      def supervisor_name,
        do: Keyword.get(__MODULE__.__info__(:attributes), :supervisor_name, []) |> List.first()

      def child_spec({%{id: id} = unit, project}) do
        %{
          id: {__MODULE__, {id, project}},
          start: {__MODULE__, :start_link, [{unit, project}]},
          restart: :permanent
        }
      end

      @impl true
      def init(arg) do
        #    Arke.Boundary.ArkeManager.create(Arke.Core.Arke.new(id: "prova", label: "okok"), :arke_system)
        {:ok, arg}
      end

      #    :code.all_loaded()
      #    set_manager(Arke.Core.Arke.new(id: "prova", label: "okok"), :arke_system)

      @spec start_link({atom | %{:id => any, optional(any) => any}, any}) ::
              :ignore | {:error, any} | {:ok, pid}
      def start_link({%{id: id, metadata: metadata} = unit, project}) do
        unit = Unit.update(unit, metadata: Map.put(metadata, :project, project))

        GenServer.start_link(
          __MODULE__,
          {unit, project},
          name: via({id, project})
        )
      end

      @doc """
        Function that identify the caller and return the right genServer to use
      """
      @spec via({any, any}) :: {:via, Registry, {any, {any, any}}}
      def via({_unit_id, _project} = name) do
        {
          :via,
          Registry,
          {registry_name, name}
        }
      end

      def get_all(project \\ :arke_system) do
        supervisor_name
        |> DynamicSupervisor.which_children()
        |> Enum.filter(&child_pid?/1)
        |> Enum.flat_map(&active_managers(&1, project, nil))
      end

      def remove(%{id: id, metadata: %{project: project}} = unit), do: remove(id, project)

      def remove(unit_id, project) do
        case get_pid(unit_id, project) do
          {:error, msg} ->
            #TODO: maybe error and not errors
            {:errors, msg}

          pid ->
            DynamicSupervisor.terminate_child(
              supervisor_name,
              pid
            )

            :ok
        end
      end

      def create(%{id: id, metadata: %{project: project}} = unit), do: create(unit, project)

      def create(unit, project) do
        {unit, project} = before_create(unit, project)

        DynamicSupervisor.start_child(
          supervisor_name,
          {__MODULE__, {unit, project}}
        )
      end

      def before_create(unit, project), do: {unit, project}

      defp child_pid?({:undefined, pid, :worker, [__MODULE__]}) when is_pid(pid), do: true
      defp child_pid?(_child), do: false

      defp active_managers({:undefined, pid, :worker, [__MODULE__]}, project, nil) do
        registry_name
        |> Registry.keys(pid)
        |> Enum.filter(fn {_arke_id, arke_project} ->
          arke_project == project
        end)
      end

      defp active_managers({:undefined, pid, :worker, [__MODULE__]}, project, unit) do
        registry_name
        |> Registry.keys(pid)
        |> Enum.filter(fn {unit_id, arke_project} ->
          arke_project == project and unit_id == unit
        end)
      end

      def is_child_alive?({unit, project}) do
        supervisor_name
        |> DynamicSupervisor.which_children()
        |> Enum.filter(&child_pid?/1)
        |> Enum.flat_map(&active_managers(&1, project, unit))
        |> Enum.any?()
      end

      def get_pid(%{id: id, metadata: %{project: project}} = unit), do: get_pid(id, project)

      def get_pid(unit_id, project) do
        try do
          GenServer.call(via({unit_id, project}), :get_pid)
        catch
          :exit, {:noproc, _} -> Error.create(__MODULE__, "Unit with id '#{unit_id}' not found")
        end
      end

      @doc """
        Return a struct with all the parameter associated for the given double schema_id, project in its GenServer.

        ## Parameters
          - arke_id => :atom => identify the schema
          - project => :atom => identify the schema's project

        ## Examples
            iex> ArkeManager.get_schema(:arke_schema, :default)
      """
      def get(unit_id, project) when is_binary(unit_id),
        do: get(String.to_existing_atom(unit_id), project)

      def get(unit_id, project) do
        case is_child_alive?({unit_id, project}) do
          false ->
            case is_child_alive?({unit_id, :arke_system}) do
              false -> Error.create(__MODULE__, "Unit with id '#{unit_id}' not found")
              true -> GenServer.call(via({unit_id, :arke_system}), :get)
            end

          true ->
            GenServer.call(via({unit_id, project}), :get)
        end
      end

      def update(%{id: id, metadata: %{project: project}} = unit, new_unit),
        do: update(id, project, new_unit)

      def update(unit_id, project, new_unit) do
        unit = get(unit_id, project)
        GenServer.call(via({unit_id, project}), {:update, new_unit})
      end

      def get_module(%{id: id, metadata: %{project: project}} = unit), do: get_module(id, project)

      def get_module(unit_id, project) do
        case is_child_alive?({unit_id, project}) do
          false ->
            case is_child_alive?({unit_id, :arke_system}) do
              false -> Error.create(:arke_manager, "Arke not found")
              true -> GenServer.call(via({unit_id, :arke_system}), :get_module)
            end

          true ->
            GenServer.call(via({unit_id, project}), :get_module)
        end
      end

      def call_func(%{id: id, metadata: %{project: project}} = unit, func, opts),
        do: call_func(id, project, func, opts)

      def call_func(unit_id, project, func, opts) do
        GenServer.call(via({unit_id, project}), {:call_func, func, opts})
      end

      def get_link(%{id: id, metadata: %{project: project}} = unit, parameter_id),
        do: get_link(id, project, parameter_id)

      def get_link(unit_id, project, parameter_id) do
        GenServer.call(via({unit_id, project}), {:get_link, parameter_id})
      end

      def add_link(
            %{id: id, metadata: %{project: project}} = unit,
            parameter_id,
            child_id,
            metadata
          ),
          do: add_link(id, project, parameter_id, child_id, metadata)

      def add_link(unit_id, project, parameter_id, child_id, metadata) do
        GenServer.call(via({unit_id, project}), {:add_link, parameter_id, child_id, metadata})
      end

      def remove_link(%{id: id, metadata: %{project: project}} = unit, parameter_id, child_id),
        do: remove_link(id, project, parameter_id, child_id)

      def remove_link(unit_id, project, parameter_id, child_id) do
        GenServer.call(via({unit_id, project}), {:remove_link, parameter_id, child_id})
      end

      # Get pid of specific unit process
      def handle_call(:get_pid, _from, {unit, project}) do
        {:reply, self(), {unit, project}}
      end

      # Get specific unit
      def handle_call(:get, _from, {unit, project}) do
        {:reply, unit, {unit, project}}
      end

      # Get remove unit
      def handle_call(:remove, _from, {unit, project}) do
        DynamicSupervisor.terminate_child(
          supervisor_name,
          self()
        )

        {:stop, :normal, :ok, {unit, project}}
      end

      # Update Unit
      def handle_call({:update, new_unit}, _from, {unit, project}) do
        {:reply, new_unit, {new_unit, project}}
      end

      # Get unit module
      def handle_call(:get_module, _from, {%{__module__: module} = unit, project}) do
        {:reply, module, {unit, project}}
      end

      # Call unit func
      def handle_call({:call_func, func, opts}, _from, {%{__module__: module} = unit, project}) do
        res = handle_call_func(module, func, opts, unit)
        {:reply, res, {unit, project}}
      end

      defp handle_call_func(nil, _, _, unit), do: {:error, "No Module"}
      defp handle_call_func(module, func, opts, _), do: apply(module, func, opts)

      # Call get link
      def handle_call({:get_link, parameter_id}, _from, {%{data: data} = unit, project}) do
        {:reply, Enum.map(Map.get(data, parameter_id, []), fn l -> l end), {unit, project}}
      end

      # Call add link
      def handle_call(
            {:add_link, parameter_id, child_id, metadata},
            _from,
            {%{data: data} = unit, project}
          ) do
        opts =
          %{}
          |> Map.put(parameter_id, [
            link_init(project, parameter_id, child_id, metadata) | Map.get(data, parameter_id, [])
          ])

        unit = Unit.update(unit, opts)
        {:reply, unit, {unit, project}}
      end

      defp link_init(project, parameter_id, child_id, metadata),
        do: %{id: child_id, metadata: metadata}

      # Call remove link
      def handle_call(
            {:remove_link, parameter_id, child_id},
            _from,
            {%{data: data} = unit, project}
          ) do
        opts =
          %{}
          |> Map.put(
            parameter_id,
            Enum.filter(Map.get(data, parameter_id, []), fn link -> link.id != child_id end)
          )

        unit = Unit.update(unit, opts)
        {:reply, unit, {unit, project}}
      end

      def terminate(reason, _s) do
        IO.inspect({self(), reason}, label: :terminate)
        :ok
      end

      defoverridable before_create: 2, link_init: 4
    end
  end

  defmacro set_registry_name(name) do
    quote do
      @registry_name unquote(name)
    end
  end

  defmacro set_supervisor_name(name) do
    quote do
      @supervisor_name unquote(name)
    end
  end
end
