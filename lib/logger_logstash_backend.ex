################################################################################
# Copyright 2015 Marcelo Gornstein <marcelog@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################
defmodule LoggerLogstashBackend do
  @behaviour :gen_event

  use Timex
  require Logger

  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end

  def handle_call({:configure, opts}, %{name: name}) do
    {:ok, :ok, configure(name, opts)}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_event(
    {level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state
  ) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event level, msg, ts, md, state
    end
    {:ok, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp log_event(
    level, msg, ts, md, %{
      host: host,
      port: port,
      type: type,
      metadata: metadata,
      socket: socket
    }
  ) do
    fields = md
             |> Keyword.merge(metadata)
             |> Enum.into(%{})
             |> Map.put(:level, to_string(level))
             |> inspect_pids

    {{year, month, day}, {hour, minute, second, milliseconds}} = ts
    {:ok, ts} = NaiveDateTime.new(
      year, month, day, hour, minute, second, (milliseconds * 1000)
    )
    ts = Timex.to_datetime ts, Timezone.local
    {:ok, json} = Poison.encode %{
      type: type,
      "@timestamp": Timex.format!(ts, "{ISO:Extended}"),
      message: to_string(msg),
      fields: Map.new(fields, fn {k, v} -> {k, inspect(v)} end),
    }
    :gen_udp.send socket, host, port, to_charlist(json)
  end

  defp configure(name, opts) do
    env  = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)

    level    = Keyword.get(opts, :level, :debug)
    metadata = Keyword.get(opts, :metadata, [])
    type     = Keyword.get(opts, :type, "elixir")
    host     = Keyword.get(opts, :host) |> get_system_value |> get_host
    port     = Keyword.get(opts, :port) |> get_system_value |> get_port

    Application.put_env(:logger, name, opts)


    {:ok, socket} = :gen_udp.open 0
    %{
      name: name,
      host: host,
      port: port,
      level: level,
      socket: socket,
      type: type,
      metadata: metadata
    }
  end

  defp get_host(nil), do: to_charlist("localhost")
  defp get_host(host), do: to_charlist(host)

  defp get_port(nil), do: 0
  defp get_port(port) do
    case Integer.parse(port) do
      {number, _} -> number
      :error ->
        IO.warn("Invalid Logstash backend port #{inspect port}")
        0
    end
  end

  defp get_system_value({:system, env_var_name}) do
    if value = System.get_env(env_var_name) do
      value
    else
      IO.warn("Logstash backend environment variable not defined: #{inspect env_var_name}")
      nil
    end
  end

  defp get_system_value(other), do: other

  # inspects the argument only if it is a pid
  defp inspect_pid(pid) when is_pid(pid), do: inspect(pid)
  defp inspect_pid(other), do: other

  # inspects the field values only if they are pids
  defp inspect_pids(fields) when is_map(fields) do
    Enum.into fields, %{}, fn {key, value} ->
      {key, inspect_pid(value)}
    end
  end
end
