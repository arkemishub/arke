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

  arke id: :arke_file, label: "Arke file" do
    parameter(:name, :string, required: true)
    parameter(:path, :string, required: true)
    parameter(:provider, :string, values: ["local", "gcloud", "aws"], default: "gcloud")
    parameter(:size, :float, required: false)
    parameter(:extension, :string, required: false)
    parameter(:binary, :bynary, required: true, only_runtime: true)
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

  # def test() do
  #   {:ok, token} = Goth.Token.fetch([])
  #   conn = GoogleApi.Storage.V1.Connection.new(token.token)

  #   # Call the Storage V1 API (for example) to list buckets
  #   {:ok, response} = GoogleApi.Storage.V1.Api.Buckets.storage_buckets_list(conn, "arkemis-lab")

  #   # Print the response
  #   Enum.each(response.items, &IO.puts(&1.id))
  # end

  # @spec upload_file :: none
  # def upload_file() do
  #   # Authenticate.
  #   {:ok, token} = Goth.Token.fetch([])
  #   conn = GoogleApi.Storage.V1.Connection.new(token.token)

  #   # Make the API request.
  #   {:ok, object} =
  #     GoogleApi.Storage.V1.Api.Objects.storage_objects_insert_iodata(
  #       conn,
  #       "arke_demo",
  #       "multipart",
  #       %{name: "file.txt"},
  #       "Hello " <> "Dorian aa" <> "!"
  #     )

  #   # Print the object.
  #   IO.puts("Uploaded #{object.name} to #{object.selfLink}")
  # end

  # def get() do
  #   {:ok, token} = Goth.Token.fetch([])
  #   conn = GoogleApi.Storage.V1.Connection.new(token.token)

  #   # Make the API request.
  #   {:ok, object} =
  #     GoogleApi.Storage.V1.Api.Objects.storage_objects_get(
  #       conn,
  #       "arke_demo",
  #       "file.txt"
  #     )
  # end

  # def get_url() do
  #   service_account = "arke-storage@arkemis-lab.iam.gserviceaccount.com"
  #   bucket = "arke_demo"
  #   object = "file.txt"

  #   get_signed_url(service_account, bucket, object)
  # end

  # def compose_signed_url(gcp_service_account, bucket, object) do
  #   %Tesla.Client{pre: [{Tesla.Middleware.Headers, :call, [auth_headers]}]} = get_connection()
  #   headers = [{"Content-Type", "application/json"}] ++ auth_headers

  #   url =
  #     "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/#{gcp_service_account}:signBlob"

  #   expires = DateTime.utc_now() |> DateTime.to_unix() |> Kernel.+(1 * 3600)
  #   resource = "/#{bucket}/#{object}"
  #   signature = ["GET", "", "", expires, resource] |> Enum.join("\n") |> Base.encode64()
  #   body = %{"payload" => signature} |> Poison.encode!()
  #   IO.inspect(HTTPoison.post(url, body, headers))
  #   {:ok, %{status_code: 200, body: result}} = HTTPoison.post(url, body, headers)

  #   %{"signedBlob" => signed_blob} = Poison.decode!(result)

  #   qs =
  #     %{
  #       "GoogleAccessId" => gcp_service_account,
  #       "Expires" => expires,
  #       "Signature" => signed_blob
  #     }
  #     |> URI.encode_query()

  #   Enum.join(["https://storage.googleapis.com#{resource}", "?", qs])
  # end

  # defp get_connection() do
  #   {:ok, token} = Goth.Token.fetch([])
  #   conn = GoogleApi.Storage.V1.Connection.new(token.token)
  # end
end
