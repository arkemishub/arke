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

defmodule Arke.Core.File do
  @moduledoc """
  Defines a file that can be used to store data
  """

  use Arke.System
  alias Arke.Utils.Gcp
  alias Arke.Boundary.ArkeManager

  arke id: :arke_file do
  end

  def before_load(
        %{path: path, content_type: content_type, filename: filename} = _,
        :create
      ) do
    {:ok, file_stat} = File.stat(path)
    extension = Path.extname(filename)
    {:ok, binary} = File.read(path)
    path = "arke_file/#{DateTime.to_string(DateTime.utc_now())}"

    unit_data = %{
      binary: binary,
      extension: extension,
      size: file_stat.size,
      provider: "gcloud",
      path: path,
      name: filename
    }

    {:ok, unit_data}
  end

  def before_load(opts, _persistence_fn), do: {:ok, opts}

  def on_struct_encode(arke, unit, data, opts) do
    load_files = Keyword.get(opts, :load_files, false)

    case load_files do
      false -> {:ok, data}
      true -> {:ok, Map.put(data, :signed_url, get_signed_url(unit))}
    end
  end

  def before_create(_, %{data: %{name: name, path: path, binary: binary}} = unit) do
    case Gcp.upload_file("#{path}/#{name}", binary) do
      {:ok, _object} -> {:ok, unit}
      {:error, error} -> {:error, error}
    end
  end

  def before_delete(_, %{data: %{name: name, path: path}} = unit) do
    case Gcp.delete_file("#{path}/#{name}") do
      {:ok, _e} -> {:ok, unit}
      {:error, error} -> {:error, error}
    end
  end

  def before_update(_, %{binary: binary} = unit) when is_nil(binary), do: {:ok, unit}

  def before_update(_, %{data: %{name: name, path: path, binary: binary}} = unit) do
    case Gcp.upload_file("#{path}/#{name}", binary) do
      {:ok, _object} -> {:ok, unit}
      {:error, error} -> {:error, error}
    end
  end

  def get_signed_url(%{data: data} = unit) do
    {:ok, signed_url} = Gcp.get_bucket_file_signed_url("#{data.path}/#{data.name}")
    signed_url
  end
end
