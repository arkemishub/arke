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

defmodule Arke do
  alias Arke.Validator
  alias Arke.Core.Unit
  alias Arke.Boundary.{ArkeManager, GroupManager, ParameterManager}
  alias Arke.Core.Parameter

  def init() do
    base_parameters()

    GroupManager.create(
      Unit.new(
        :parameter,
        %{label: "Parameter", description: "Parameter Group", arke_list: []},
        :group,
        nil,
        %{},
        nil,
        nil,
        nil
      ),
      :arke_system
    )

    GroupManager.create(
      Unit.new(
        :arke_or_group,
        %{label: "Arke or Group", description: "Arke or Group", arke_list: []},
        :group,
        nil,
        %{},
        nil,
        nil,
        nil
      ),
      :arke_system
    )

    arke_modules = get_arke_modules()
  end

  defp get_arke_modules() do
    Enum.reduce(:application.loaded_applications(), [], fn {app, _, _}, arke_list ->
      {:ok, modules} = :application.get_key(app, :modules)

      module_arke_list =
        Enum.reduce(modules, [], fn mod, mod_arke_list ->
          is_arke =
            Code.ensure_loaded?(mod) and :erlang.function_exported(mod, :arke_from_attr, 0) and
              mod.arke_from_attr != nil

          mod_arke_list = check_arke_module(mod, mod_arke_list, is_arke)
        end)

      arke_list ++ module_arke_list
    end)
  end

  defp check_arke_module(mod, arke_list, true) do
    %{id: id, data: data, metadata: metadata} = mod.arke_from_attr
    unit = Unit.new(id, data, :arke, nil, metadata, nil, nil, mod)

    ArkeManager.create(unit, :arke_system)

    Enum.map(mod.groups_from_attr, fn %{id: parent_id, metadata: link_metadata} ->
      GroupManager.add_link(parent_id, :arke_system, :arke_list, id, link_metadata)
    end)

    [mod | arke_list]
  end

  defp check_arke_module(_, arke_list, false), do: arke_list

  defp base_parameter(opts \\ []) do
    %{
      label: Keyword.get(opts, :label),
      #      type: Keyword.get!(opts, :type),
      format: Keyword.get(opts, :format, :attribute),
      is_primary: Keyword.get(opts, :is_primary, false),
      nullable: Keyword.get(opts, :nullable, true),
      required: Keyword.get(opts, :required, false),
      persistence: Keyword.get(opts, :persistence, "arke_parameter"),
      helper_text: Keyword.get(opts, :label, nil)
    }
  end

  defp base_parameters() do
    id =
      Unit.new(
        :id,
        Map.merge(
          base_parameter(
            label: "Id",
            is_primary: true,
            nullable: false,
            required: true,
            persistence: "table_column"
          ),
          %{
            min_length: 2,
            max_length: nil,
            values: nil,
            multiple: false,
            unique: true,
            default_string: nil,
            strip: true
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    arke_id =
      Unit.new(
        :arke_id,
        Map.merge(
          base_parameter(
            label: "Arke id",
            nullable: false,
            required: true,
            persistence: "table_column"
          ),
          %{
            min_length: 2,
            max_length: nil,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil,
            strip: true
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    metadata =
      Unit.new(
        :metadata,
        Map.merge(
          base_parameter(label: "Metadata", persistence: "table_column"),
          %{default_dict: %{}}
        ),
        :dict,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    inserted_at =
      Unit.new(
        :inserted_at,
        Map.merge(
          base_parameter(label: "Inserted at", persistence: "table_column"),
          %{default_datetime: nil}
        ),
        :datetime,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    updated_at =
      Unit.new(
        :updated_at,
        Map.merge(
          base_parameter(label: "Updated at", persistence: "table_column"),
          %{default_datetime: nil}
        ),
        :datetime,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    active =
      Unit.new(
        :active,
        Map.merge(
          base_parameter(label: "Active", nullable: false),
          %{default_boolean: true}
        ),
        :boolean,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    label =
      Unit.new(
        :label,
        Map.merge(
          base_parameter(label: "Label", nullable: false, required: true),
          %{
            min_length: 2,
            max_length: 200,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    format =
      Unit.new(
        :format,
        Map.merge(
          base_parameter(label: "Format", nullable: false),
          %{
            min_length: 2,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: "attribute"
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    is_primary =
      Unit.new(
        :is_primary,
        Map.merge(
          base_parameter(label: "Is Primary", nullable: false),
          %{default_boolean: false}
        ),
        :boolean,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    nullable =
      Unit.new(
        :nullable,
        Map.merge(
          base_parameter(label: "Nullable", nullable: false),
          %{default_boolean: true}
        ),
        :boolean,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    required =
      Unit.new(
        :required,
        Map.merge(
          base_parameter(label: "Required", nullable: false),
          %{default_boolean: false}
        ),
        :boolean,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    persistence =
      Unit.new(
        :persistence,
        Map.merge(
          base_parameter(label: "Persistence", nullable: false),
          %{
            min_length: 2,
            max_length: nil,
            strip: false,
            values: [
              %{label: "Arke Parameter", value: "arke_parameter"},
              %{label: "Table Column", value: "table_column"}
            ],
            multiple: false,
            unique: false,
            default_string: "arke_parameter"
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    helper_text =
      Unit.new(
        :helper_text,
        Map.merge(
          base_parameter(label: "Helper text", nullable: true),
          %{
            min_length: 2,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    min_length =
      Unit.new(
        :min_length,
        Map.merge(
          base_parameter(label: "Min Length"),
          %{min: nil, max: nil, values: nil, multiple: false, unique: false, default_integer: nil}
        ),
        :integer,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    max_length =
      Unit.new(
        :max_length,
        Map.merge(
          base_parameter(label: "Max Length"),
          %{min: nil, max: nil, values: nil, multiple: false, unique: false, default_integer: nil}
        ),
        :integer,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    strip =
      Unit.new(
        :strip,
        Map.merge(
          base_parameter(label: "Remove Whitespace"),
          %{default_boolean: false}
        ),
        :boolean,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    token =
      Unit.new(
        :token,
        Map.merge(
          base_parameter(label: "Token"),
          %{
            min_length: 3,
            max_length: nil,
            strip: true,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    expiration =
      Unit.new(
        :expiration,
        Map.merge(
          base_parameter(label: "Expiration date"),
          %{default_datetime: nil}
        ),
        :datetime,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    values =
      Unit.new(
        :values,
        Map.merge(
          base_parameter(label: "Values"),
          %{default_list: nil}
        ),
        :list,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    multiple =
      Unit.new(
        :multiple,
        Map.merge(
          base_parameter(label: "Multiple", nullable: false),
          %{default_boolean: false}
        ),
        :boolean,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    unique =
      Unit.new(
        :unique,
        Map.merge(
          base_parameter(label: "Unique", nullable: false),
          %{default_boolean: false}
        ),
        :boolean,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    min =
      Unit.new(
        :min,
        Map.merge(
          base_parameter(label: "Min"),
          %{min: nil, max: nil, values: nil, multiple: false, unique: false, default_integer: nil}
        ),
        :integer,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    max =
      Unit.new(
        :max,
        Map.merge(
          base_parameter(label: "Max"),
          %{min: nil, max: nil, values: nil, multiple: false, unique: false, default_integer: nil}
        ),
        :integer,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_integer =
      Unit.new(
        :default_integer,
        Map.merge(
          base_parameter(label: "Default"),
          %{min: nil, max: nil, values: nil, multiple: false, unique: false, default_integer: nil}
        ),
        :integer,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_float =
      Unit.new(
        :default_float,
        Map.merge(
          base_parameter(label: "Default"),
          %{min: nil, max: nil, values: nil, multiple: false, unique: false, default_float: nil}
        ),
        :float,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_string =
      Unit.new(
        :default_string,
        Map.merge(
          base_parameter(label: "Default"),
          %{
            min_length: nil,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_boolean =
      Unit.new(
        :default_boolean,
        Map.merge(
          base_parameter(label: "Default"),
          %{default_boolean: nil}
        ),
        :boolean,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_dict =
      Unit.new(
        :default_dict,
        Map.merge(
          base_parameter(label: "Default"),
          %{default_dict: nil}
        ),
        :dict,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_list =
      Unit.new(
        :default_list,
        Map.merge(
          base_parameter(label: "Default"),
          %{default_list: nil}
        ),
        :list,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_date =
      Unit.new(
        :default_date,
        Map.merge(
          base_parameter(label: "Default"),
          %{default_date: nil}
        ),
        :date,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_time =
      Unit.new(
        :default_time,
        Map.merge(
          base_parameter(label: "Default"),
          %{default_time: nil}
        ),
        :time,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_datetime =
      Unit.new(
        :default_datetime,
        Map.merge(
          base_parameter(label: "Default"),
          %{default_datetime: nil}
        ),
        :datetime,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_link =
      Unit.new(
        :default_link,
        Map.merge(
          base_parameter(label: "Default"),
          %{
            default_link: nil,
            multiple: false,
            arke_or_group_id: nil,
            depth: 0,
            connection_type: "link",
            filter_keys: ["arke_id", "id"]
          }
        ),
        :link,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_dynamic =
      Unit.new(
        :default_dynamic,
        Map.merge(
          base_parameter(label: "Default"),
          %{default_dynamic: nil}
        ),
        :dynamic,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    default_binary =
      Unit.new(
        :default_binary,
        Map.merge(
          base_parameter(label: "Default"),
          %{default_binary: nil}
        ),
        :binary,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    description =
      Unit.new(
        :description,
        Map.merge(
          base_parameter(label: "Description"),
          %{
            min_length: 0,
            max_length: 500,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    arke_list =
      Unit.new(
        :arke_list,
        Map.merge(
          base_parameter(label: "Arke List"),
          %{default_link: [], multiple: true, filter_keys: ["arke_id", "id"]}
        ),
        :link,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    parameters =
      Unit.new(
        :parameters,
        Map.merge(
          base_parameter(label: "Parameters"),
          %{default_link: [], depth: 0, connection_type: "link", multiple: false}
        ),
        :link,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    child_id =
      Unit.new(
        :child_id,
        Map.merge(
          base_parameter(label: "Child Id"),
          %{
            min_length: 2,
            max_length: nil,
            strip: true,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    parent_id =
      Unit.new(
        :parent_id,
        Map.merge(
          base_parameter(label: "Parent Id"),
          %{
            min_length: 2,
            max_length: nil,
            strip: true,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    type =
      Unit.new(
        :type,
        Map.merge(
          base_parameter(label: "Type"),
          %{
            min_length: 2,
            max_length: nil,
            strip: true,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    name =
      Unit.new(
        :name,
        Map.merge(
          base_parameter(label: "Name"),
          %{
            min_length: 2,
            max_length: 100,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    public_key =
      Unit.new(
        :public_key,
        Map.merge(
          base_parameter(label: "Public Key"),
          %{
            min_length: 2,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    email =
      Unit.new(
        :email,
        Map.merge(
          base_parameter(label: "Email"),
          %{
            min_length: 2,
            max_length: nil,
            strip: true,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    vat =
      Unit.new(
        :vat,
        Map.merge(
          base_parameter(label: "Vat"),
          %{
            min_length: 2,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    environment =
      Unit.new(
        :environment,
        Map.merge(
          base_parameter(label: "Environment"),
          %{
            min_length: 2,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    username =
      Unit.new(
        :username,
        Map.merge(
          base_parameter(label: "Username"),
          %{
            min_length: 3,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    password_hash =
      Unit.new(
        :password_hash,
        Map.merge(
          base_parameter(label: "Password hash"),
          %{
            min_length: 3,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    first_name =
      Unit.new(
        :first_name,
        Map.merge(
          base_parameter(label: "First name"),
          %{
            min_length: 3,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    last_name =
      Unit.new(
        :last_name,
        Map.merge(
          base_parameter(label: "Last name"),
          %{
            min_length: 3,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    fiscal_code =
      Unit.new(
        :fiscal_code,
        Map.merge(
          base_parameter(label: "Fiscal code"),
          %{
            min_length: 3,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    address =
      Unit.new(
        :address,
        Map.merge(
          base_parameter(label: "Address"),
          %{default_dict: nil}
        ),
        :dict,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    phone_number =
      Unit.new(
        :phone_number,
        Map.merge(
          base_parameter(label: "Phone number"),
          %{
            min_length: 1,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    birth_date =
      Unit.new(
        :birth_date,
        Map.merge(
          base_parameter(label: "Birth date"),
          %{
            min_length: 1,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    user_id =
      Unit.new(
        :user_id,
        Map.merge(
          base_parameter(label: "Unit id"),
          %{
            min_length: 1,
            max_length: nil,
            strip: true,
            values: nil,
            multiple: false,
            unique: false,
            default_string: nil
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    first_access =
      Unit.new(
        :first_access,
        Map.merge(
          base_parameter(label: "First access"),
          %{default_boolean: true}
        ),
        :boolean,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    last_login =
      Unit.new(
        :last_login,
        Map.merge(
          base_parameter(label: "Last login", persistence: "table_column"),
          %{default_datetime: nil}
        ),
        :datetime,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    connection_type =
      Unit.new(
        :connection_type,
        Map.merge(
          base_parameter(label: "Connection type"),
          %{
            min_length: 1,
            max_length: nil,
            strip: true,
            values: nil,
            multiple: false,
            unique: false,
            default_string: "link"
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    depth =
      Unit.new(
        :depth,
        Map.merge(
          base_parameter(label: "Depth"),
          %{min: 0, max: 100, values: nil, multiple: false, unique: false, default_integer: 0}
        ),
        :integer,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    arke_or_group_id =
      Unit.new(
        :arke_or_group_id,
        Map.merge(base_parameter(label: "Arke or Group id", required: true), %{
          default_link: nil,
          multiple: false,
          arke_or_group_id: "arke_or_group",
          depth: 0,
          connection_type: "link",
          filter_keys: ["id", "label"]
        }),
        :link,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    filter_keys =
      Unit.new(
        :filter_keys,
        Map.merge(
          base_parameter(label: "Filter keys"),
          %{
            min_length: nil,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: true,
            unique: false,
            default_string: []
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    only_run_time =
      Unit.new(
        :only_run_time,
        Map.merge(
          base_parameter(label: "Only run time"),
          %{default_boolean: false}
        ),
        :boolean,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    path =
      Unit.new(
        :path,
        Map.merge(
          base_parameter(label: "Path"),
          %{
            min_length: nil,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: ""
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    provider =
      Unit.new(
        :provider,
        Map.merge(
          base_parameter(label: "Provider"),
          %{
            min_length: nil,
            max_length: nil,
            strip: false,
            values: ["local", "gcloud", "aws"],
            multiple: false,
            unique: false,
            default_string: "gcloud"
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    extension =
      Unit.new(
        :extension,
        Map.merge(
          base_parameter(label: "Extension"),
          %{
            min_length: nil,
            max_length: nil,
            strip: false,
            values: nil,
            multiple: false,
            unique: false,
            default_string: ""
          }
        ),
        :string,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    binary =
      Unit.new(
        :binary,
        Map.merge(
          base_parameter(label: "Binary"),
          %{default_binary: nil}
        ),
        :binary,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    size =
      Unit.new(
        :size,
        Map.merge(
          base_parameter(label: "Size"),
          %{min: 0, max: nil, values: nil, multiple: false, unique: false, default_float: nil}
        ),
        :float,
        nil,
        %{},
        nil,
        nil,
        nil
      )

    parameters = [
      id,
      arke_id,
      metadata,
      inserted_at,
      updated_at,
      active,
      label,
      format,
      is_primary,
      nullable,
      required,
      persistence,
      helper_text,
      strip,
      min_length,
      max_length,
      values,
      multiple,
      unique,
      min,
      max,
      default_integer,
      default_float,
      default_string,
      default_boolean,
      default_dict,
      default_list,
      default_date,
      default_time,
      default_datetime,
      default_dynamic,
      default_binary,
      description,
      arke_list,
      parameters,
      child_id,
      parent_id,
      type,
      name,
      public_key,
      email,
      vat,
      environment,
      username,
      password_hash,
      first_name,
      last_name,
      fiscal_code,
      address,
      phone_number,
      first_access,
      last_login,
      birth_date,
      default_link,
      connection_type,
      depth,
      arke_or_group_id,
      filter_keys,
      only_run_time,
      path,
      provider,
      extension,
      binary,
      size,
      expiration,
      token,
      user_id
    ]

    Enum.map(parameters, fn parameter ->
      Arke.Boundary.ParamsManager.create(parameter, :arke_system)
      ParameterManager.create(parameter, :arke_system)
    end)
  end
end
