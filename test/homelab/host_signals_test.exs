defmodule Homelab.HostSignalsTest do
  use ExUnit.Case, async: true

  alias Homelab.HostSignals

  setup do
    tmp = Path.join(System.tmp_dir!(), "host_signals-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    reboot_path = Path.join(tmp, "reboot-required")
    uptime_path = Path.join(tmp, "uptime")

    previous = Application.get_env(:homelab, Homelab.HostSignals)

    Application.put_env(:homelab, Homelab.HostSignals,
      reboot_required_path: reboot_path,
      uptime_path: uptime_path
    )

    on_exit(fn -> Application.put_env(:homelab, Homelab.HostSignals, previous) end)

    %{reboot_path: reboot_path, uptime_path: uptime_path}
  end

  test "reports reboot required when file exists", %{reboot_path: reboot_path} do
    File.write!(reboot_path, "")

    assert HostSignals.status().reboot_required? == {:ok, true}

    File.rm!(reboot_path)

    assert HostSignals.status().reboot_required? == {:ok, false}
  end

  test "parses uptime data", %{uptime_path: uptime_path} do
    File.write!(uptime_path, "172800.0 0.0")

    assert {:ok, %{seconds: 172_800, human: human}} = HostSignals.status().uptime
    assert human == "2 days, 0 hours, 0 mins"
  end

  test "invalid uptime format surfaces error", %{uptime_path: uptime_path} do
    File.write!(uptime_path, "oops")

    assert {:error, :invalid_format} = HostSignals.status().uptime
  end
end
