#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

board="config/boards/avaota-a1.csc"
customize="userpatches/customize-image.sh"
script="userpatches/overlay/usr/local/sbin/avaota-firstlogin-console"
service="userpatches/overlay/etc/systemd/system/avaota-firstlogin-console.service"

assert_not_contains() {
	local pattern="$1" file="$2"
	if grep -Eq -- "${pattern}" "${file}"; then
		echo "Unexpected pattern '${pattern}' in ${file}" >&2
		exit 1
	fi
}

grep -q 'console=tty1' "${board}"
assert_not_contains 'console=tty0' "${board}"
assert_not_contains '^PLYMOUTH="no"$' "${board}"
assert_not_contains '^MAIN_CMDLINE=' "${board}"
grep -q '^function post_family_config__avaota_a1_console_cmdline()' "${board}"

# common.conf is sourced after the board file, so verify the late board hook
# removes its splash arguments instead of relying on a top-level assignment.
MAIN_CMDLINE='rw no_console_suspend splash plymouth.ignore-serial-consoles'
# shellcheck source=/dev/null
source "${board}"
post_family_config__avaota_a1_console_cmdline
if [[ "${MAIN_CMDLINE}" != 'rw no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0' ]]; then
	echo "Unexpected late MAIN_CMDLINE override: ${MAIN_CMDLINE}" >&2
	exit 1
fi
grep -q 'plymouth.enable=0' "${board}"
grep -q 'vt.global_cursor_default=1' "${board}"
grep -q 'video=HDMI-A-1:1920x1080@60e' "${board}"
assert_not_contains 'video=LVDS-1' "${board}"

test -f "${script}"
test -f "${service}"

grep -q 'ConditionPathExists=/root/.not_logged_in_yet' "${service}"
grep -q 'Before=.*display-manager.service' "${service}"
grep -q 'Before=.*lightdm.service' "${service}"
grep -q 'Wants=getty@tty1.service' "${service}"
grep -q 'ExecStart=/usr/local/sbin/avaota-firstlogin-console' "${service}"
grep -q 'WantedBy=multi-user.target' "${service}"
grep -q 'WantedBy=.*graphical.target' "${service}"

grep -q 'plymouth quit' "${script}"
grep -q 'systemctl .*stop .*display-manager.service .*lightdm.service' "${script}"
grep -q 'systemctl .*restart .*getty@tty1.service' "${script}"
grep -q 'chvt 1' "${script}"

grep -q '/usr/local/sbin/avaota-firstlogin-console' "${customize}"
grep -q 'systemctl enable avaota-firstlogin-console.service' "${customize}"

echo "Avaota first-login console gate checks passed"
