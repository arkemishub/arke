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

defmodule Arke.Core.Parameter do
  @moduledoc """
  This module defines the parameter group and its functions.
    By default, the Arke members are:

    - `string`
    - `integer`
    - `float`
    - `boolean`
    - `dict`
    - `date`
    - `time`
    - `datetime`

  It is used to share common gen servers functions across the Arkes. In this way we have a single point of
  access to the ParameterManager and all its CRUD operations. It also does not interfere with all the `Arke.System.__using__/1`
  overridable functions defined in each module
  """
  alias Arke.Boundary.ParameterManager


  @type parameter_struct() ::
          Parameter.Boolean.t()
          | Parameter.String.t()
          | Parameter.Dict.t()
          | Parameter.Integer.t()
          | Parameter.Float.t()


  use Arke.System.Group

  group id: "parameter" do
  end

  def on_unit_create(_arke, %{id: _id, metadata: %{project: _project}} = unit) do
    ParameterManager.create(unit)
    {:ok, unit}
  end

  def on_unit_update(_arke, %{id: id, metadata: %{project: project}} = unit) do
    ParameterManager.update(id, project, unit)
    {:ok, unit}
  end

  def on_unit_delete(_arke, %{id: _id, metadata: %{project: _project}} = unit) do
    ParameterManager.remove(unit)
    {:ok, unit}
  end

end

defmodule Arke.Core.Parameter.String do
  @moduledoc false
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke id: "string" do
  end

  def before_load(data, _persistence_fn) do
    args = Arke.System.BaseParameter.check_enum(:string, Map.to_list(data))
    {:ok, Enum.into(args, %{})}
  end

end

defmodule Arke.Core.Parameter.Integer do
  @moduledoc false
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke id: "integer" do
  end

  def before_load(data, _persistence_fn) do
    args = Arke.System.BaseParameter.check_enum(:integer, Map.to_list(data))
    {:ok, Enum.into(args, %{})}
  end

end

defmodule Arke.Core.Parameter.Float do
  @moduledoc false
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke id: "float" do
  end

  def before_load(data, _persistence_fn) do
    args = Arke.System.BaseParameter.check_enum(:float, Map.to_list(data))
    {:ok, Enum.into(args, %{})}
  end

end

defmodule Arke.Core.Parameter.Boolean do
  @moduledoc false
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke id: "boolean"  do
  end
end

defmodule Arke.Core.Parameter.Dict do
  @moduledoc false
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke id: "dict" do
  end
end

defmodule Arke.Core.Parameter.List do
  @moduledoc false
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke id: "list" do
  end
end

defmodule Arke.Core.Parameter.Date do
  @moduledoc false

  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke id: "date" do
  end
end

defmodule Arke.Core.Parameter.Time do
  @moduledoc false

  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke id: "time" do
  end

end

defmodule Arke.Core.Parameter.DateTime do
  @moduledoc false

  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke id: "datetime" do
  end
end

defmodule Arke.Core.Parameter.Link do
  @moduledoc false
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke  id: "link" do
  end

end

defmodule Arke.Core.Parameter.Dynamic do
  @moduledoc false
  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  
  use Arke.System

  arke id: "dynamic" do
  end
end

defmodule Arke.Core.Parameter.Binary do
  @moduledoc false

  alias Arke.Core.Parameter
  alias Arke.Boundary.ParameterManager
  use Arke.System

  arke id: "binary" do
  end

end
