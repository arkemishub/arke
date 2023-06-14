defmodule Arke.Boundary.ParamsManager do
  @moduledoc false
  alias Arke.Core.{Unit}
  alias Arke.Boundary.ArkeManager

  use GenServer

  @persistence Application.get_env(:arke, :persistence)

  def init(parameters) when is_map(parameters) do
    {:ok, parameters}
  end

  def init(_parameters), do: {:error, "parameters must be a map"}

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, %{}, options)
  end

  def get_from_persistence() do
    GenServer.call(__MODULE__, {:get_from_persistence})
  end

  def create(manager \\ __MODULE__, parameter, project)

  def create(manager, parameter, namespace) do
    GenServer.call(manager, {:create, parameter, namespace})
  end

  def get_all(manager \\ __MODULE__) do
    GenServer.call(manager, {:get_all})
  end

  def get(manager \\ __MODULE__, unit_id, project)

  def get(manager, parameter_id, namespace) do
    GenServer.call(manager, {:get, parameter_id, namespace})
  end

  def remove(manager \\ __MODULE__, parameter_id, namespace)

  def remove(manager, parameter_id, namespace) do
    GenServer.call(manager, {:remove, parameter_id, namespace})
  end

  def handle_call({:get_from_persistence}, _from, parameters) do
    get_parameters = @persistence[:arke_postgres][:get_parameters]

    #    parameters = Arke.QueryManager.filter_by(arke_id__in: ["boolean", "dict", "float", "integer", "string", "unit"])
    pars =
      Enum.reduce(get_parameters.(), parameters, fn %{arke: arke, data: data} = parameter,
                                                    new_parameters ->
        opts = Enum.map(data, fn {key, value} -> {key, value} end)
        p = Arke.Core.Parameter.new(%{type: arke.id, opts: opts})
        new_parameters = Map.put(new_parameters, {p.id, :arke_system}, p)
      end)

    {:reply, :ok, pars}
  end

  def handle_call({:create, parameter, namespace}, _from, parameters) do
    new_parameters = Map.put(parameters, {parameter.id, namespace}, parameter)
    {:reply, :ok, new_parameters}
  end

  def handle_call({:get_all}, _from, parameters) do
    pars =
      Enum.reduce(parameters, [], fn {key, parameter}, pars ->
        [parameter | pars]
      end)

    {:reply, pars, parameters}
  end

  def handle_call({:get, parameter_id, namespace}, _from, parameters) do
    parameter_id = handle_atoms(parameter_id)

    with nil <- Map.get(parameters, {parameter_id, namespace}, nil),
         do: {:reply, Map.get(parameters, {parameter_id, :arke_system}, nil), parameters},
         else: (p -> {:reply, p, parameters})
  end

  def handle_call({:remove, parameter_id, namespace}, _from, parameters) do
    new_parameters = Map.delete(parameters, {parameter_id, namespace})
    {:reply, :ok, new_parameters}
  end

  defp handle_atoms(val) when is_binary(val), do: String.to_existing_atom(val)
  defp handle_atoms(val), do: val
end
