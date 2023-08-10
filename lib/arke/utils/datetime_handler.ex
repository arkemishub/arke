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

defmodule Arke.DatetimeHandler do
  use Timex

  @datetime_msg "must be %DateTime | %NaiveDatetime{} | ~N[YYYY-MM-DDTHH:MM:SS] | ~N[YYYY-MM-DD HH:MM:SS] | ~U[YYYY-MM-DD HH:MM:SS]  format"

  @date_msg "must be %Date{} | ~D[YYYY-MM-DD] | iso8601 (YYYY-MM-DD) format"

  @time_msg "must be must be %Time{} |~T[HH:MM:SS] | iso8601 (HH:MM:SS) format"

  defp check_datetime(v, only_value) do
    case Timex.is_valid?(v) do
      true ->
        datetime = Timex.to_datetime(v, "Etc/UTC")

        case only_value do
          true -> datetime
          false -> {:ok, datetime}
        end

      false ->
        {:error, @datetime_msg}
    end
  end

  defp check_date(v, only_value) do
    case Timex.is_valid?(v) do
      true ->
        date = Timex.to_date(v)

        case only_value do
          true -> date
          false -> {:ok, date}
        end

      false ->
        {:error, @date_msg}
    end
  end

  defp check_time(v, only_value) do
    try do
      # it will crash if the time is not valid the return the %Time{}
      Time.to_iso8601(v)

      case only_value do
        true -> v
        false -> {:ok, v}
      end
    rescue
      e ->
        {:error, @time_msg}
    end
  end

  # ----- DATETIME -----

  def now(:datetime), do: Timex.set(Timex.now(), microsecond: 0)
  def from_unix(s, unit \\ :second), do: Timex.from_unix(s, unit)
  def parse_datetime(value, only_value \\ false)
  def parse_datetime(value, true) when is_nil(value), do: value
  def parse_datetime(value, _only_value) when is_nil(value), do: {:ok, value}

  def parse_datetime(%DateTime{} = value, only_value), do: check_datetime(value, only_value)

  def parse_datetime(%NaiveDateTime{} = value, only_value), do: check_datetime(value, only_value)

  def parse_datetime(value, only_value) do
    case Timex.parse(value, "{ISO:Extended:Z}") do
      {:ok, datetime} -> check_datetime(datetime, only_value)
      {:error, _} -> {:error, @datetime_msg}
    end
  end

  # ----- DATE -----
  def now(:date), do: Timex.now() |> Timex.to_date()
  def parse_date(value, only_value \\ false)
  def parse_date(value, true) when is_nil(value), do: nil
  def parse_date(value, _only_value) when is_nil(value), do: {:ok, nil}

  def parse_date(%Date{} = value, only_value), do: check_date(value, only_value)

  def parse_date(value, only_value) do
    case Timex.parse(value, "{ISOdate}") do
      {:ok, parsed} -> check_date(parsed, only_value)
      {:error, _} -> {:error, @date_msg}
    end
  end

  # ----- TIME -----

  def now(:time), do: Time.utc_now() |> Time.truncate(:second)
  def parse_time(value, only_value \\ false)
  def parse_time(value, true) when is_nil(value), do: nil
  def parse_time(value, _only_value) when is_nil(value), do: {:ok, nil}
  def parse_time(value, _only_value) when is_number(value), do: {:error, @time_msg}

  def parse_time(%Time{} = value, only_value), do: check_time(value, only_value)

  def parse_time(value, only_value) do
    case Time.from_iso8601(value) do
      {:ok, time} ->
        case only_value do
          true ->
            time

          false ->
            {:ok, time}
        end

      {:error, _} ->
        {:error, @time_msg}
    end
  end
end
