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

defmodule Arke.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Arke.Boundary.ParamsManager, [name: Arke.Boundary.ParamsManager]},
      {Registry, [name: :parameter_registry, keys: :unique]},
      {DynamicSupervisor, [name: :parameter_supervisor, strategy: :one_for_one]},
      {Registry, [name: :arke_registry, keys: :unique]},
      {DynamicSupervisor, [name: :arke_supervisor, strategy: :one_for_one]},
      {Registry, [name: :group_registry, keys: :unique]},
      {DynamicSupervisor, [name: :group_supervisor, strategy: :one_for_one]}
      # Starts a worker by calling: ArkeMonorepo.Worker.start_link(arg)
      # {ArkeMonorepo.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Arke.Supervisor]
    link = Supervisor.start_link(children, opts)

    Arke.init()

    link
  end
end
