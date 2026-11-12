#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

board="config/boards/avaota-a1.csc"
customize="userpatches/customize-image.sh"
hotplug="userpatches/overlay/usr/local/sbin/avaota-hdmi-hotplug"
service="userpatches/overlay/etc/systemd/system/avaota-hdmi-hotplug.service"
udev_rule="userpatches/overlay/etc/udev/rules.d/99-avaota-hdmi-hotplug.rules"

grep -q 'console=tty1' "${board}"
grep -q 'video=HDMI-A-1:1920x1080@60e' "${board}"
grep -q 'Option "Monitor-HDMI-1" "Avaota HDMI"' "${board}"
grep -q 'Option "PreferredMode" "1920x1080"' "${board}"

test -f "${hotplug}"
test -f "${service}"
test -f "${udev_rule}"

grep -q 'SYSTEMD_WANTS.*avaota-hdmi-hotplug.service' "${udev_rule}"
grep -q '/usr/local/sbin/avaota-hdmi-hotplug' "${customize}"
grep -q 'systemctl enable avaota-hdmi-hotplug.service' "${customize}"
grep -q 'ATF_COMPILE=.no.' config/sources/families/sun55iw3-syterkit.conf
