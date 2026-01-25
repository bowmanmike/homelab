defmodule Homelab.HostSignals do
  @moduledoc """
  Provides read-only access to host-level signals exposed to the container,
  such as reboot requirements and uptime.
  """

  @type status :: %{
          reboot_required?: {:ok, boolean()} | {:error, term()},
          uptime: {:ok, %{seconds: non_neg_integer(), human: String.t()}} | {:error, term()}
        }

  @spec status() :: status()
  def status do
    %{
      reboot_required?: reboot_required(),
      uptime: uptime()
    }
  end

  defp reboot_required do
    path = config(:reboot_required_path)

    case File.stat(path) do
      {:ok, _} -> {:ok, true}
      {:error, :enoent} -> {:ok, false}
      {:error, reason} -> {:error, reason}
    end
  end

  defp uptime do
    path = config(:uptime_path)

    with {:ok, content} <- File.read(path),
         [uptime_seconds | _] <- String.split(content, ~r/\s+/, trim: true),
         {seconds_float, _} <- Float.parse(uptime_seconds) do
      seconds = trunc(seconds_float)

      {:ok, %{seconds: seconds, human: humanize_duration(seconds)}}
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, :invalid_format}
      [] -> {:error, :invalid_format}
    end
  end

  defp humanize_duration(seconds) when is_integer(seconds) and seconds >= 0 do
    days = div(seconds, 86_400)
    hours = div(rem(seconds, 86_400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    []
    |> maybe_prepend(days > 0, pluralize(days, "day"))
    |> Kernel.++([pluralize(hours, "hour"), pluralize(minutes, "min")])
    |> Enum.join(", ")
  end

  defp pluralize(value, unit) when value == 1, do: "1 #{unit}"
  defp pluralize(value, unit), do: "#{value} #{unit}s"

  defp maybe_prepend(list, true, value), do: [value | list]
  defp maybe_prepend(list, false, _value), do: list

  defp config(key) do
    Application.fetch_env!(:homelab, __MODULE__)
    |> Keyword.fetch!(key)
  end
end
