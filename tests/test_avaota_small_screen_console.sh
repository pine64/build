#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

board="config/boards/avaota-a1.csc"
customize="userpatches/customize-image.sh"
helper="userpatches/overlay/usr/local/sbin/avaota-small-screen-console"
service="userpatches/overlay/etc/systemd/system/avaota-small-screen-console.service"
hotplug="userpatches/overlay/usr/local/sbin/avaota-hdmi-hotplug"

assert_not_contains() {
	local pattern="$1" file="$2"
	if grep -Eq -- "${pattern}" "${file}"; then
		echo "Unexpected pattern '${pattern}' in ${file}" >&2
		exit 1
	fi
}

grep -q 'console=tty1' "${board}"
grep -q 'video=HDMI-A-1:1920x1080@60e' "${board}"
assert_not_contains 'video=LVDS-1' "${board}"

test -f "${helper}"
test -f "${service}"
grep -Eq 'apt-get install .*|^[[:space:]]*.*fbset' "${customize}"
grep -q '/usr/local/sbin/avaota-small-screen-console' "${customize}"
grep -q 'systemctl enable avaota-small-screen-console.service' "${customize}"
assert_not_contains 'avaota-dual-display' "${customize}"
assert_not_contains 'xfce4-terminal' "${customize}"
assert_not_contains 'wmctrl' "${customize}"
assert_not_contains 'avaota-dual-display' "${hotplug}"

grep -q '^After=systemd-modules-load.service' "${service}"
grep -q '^Before=.*display-manager.service' "${service}"
grep -q '^Before=.*lightdm.service' "${service}"
grep -q '^Wants=getty@tty2.service' "${service}"
grep -q '^ExecStart=/usr/local/sbin/avaota-small-screen-console' "${service}"
grep -q '^WantedBy=multi-user.target' "${service}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
mkdir -p "${tmpdir}/bin"
command_log="${tmpdir}/commands.log"

make_logger() {
	local name="$1"
	cat > "${tmpdir}/bin/${name}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '${name}' >> "\${AVAOTA_COMMAND_LOG}"
printf ' %q' "\$@" >> "\${AVAOTA_COMMAND_LOG}"
printf '\n' >> "\${AVAOTA_COMMAND_LOG}"
EOF
	chmod 755 "${tmpdir}/bin/${name}"
}

make_logger con2fbmap
make_logger systemctl
make_logger chvt
make_logger sleep

cat > "${tmpdir}/bin/fgconsole" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${AVAOTA_FOREGROUND_VT:-1}"
EOF
chmod 755 "${tmpdir}/bin/fgconsole"

framebuffer="${tmpdir}/fb1"
touch "${framebuffer}"
: > "${command_log}"

AVAOTA_COMMAND_LOG="${command_log}" \
	FRAMEBUFFER_DEVICE="${framebuffer}" \
	FRAMEBUFFER_INDEX=1 \
	CONSOLE_NUMBER=2 \
	WAIT_ATTEMPTS=1 \
	WAIT_INTERVAL=0 \
	CON2FBMAP_BIN="${tmpdir}/bin/con2fbmap" \
	SYSTEMCTL_BIN="${tmpdir}/bin/systemctl" \
	FGCONSOLE_BIN="${tmpdir}/bin/fgconsole" \
	CHVT_BIN="${tmpdir}/bin/chvt" \
	SLEEP_BIN="${tmpdir}/bin/sleep" \
	"${helper}"

grep -qx "con2fbmap 2 1" "${command_log}"
grep -qx "systemctl start getty@tty2.service" "${command_log}"
grep -qx "chvt 2" "${command_log}"
grep -qx "chvt 1" "${command_log}"

: > "${command_log}"
AVAOTA_COMMAND_LOG="${command_log}" \
	FRAMEBUFFER_DEVICE="${tmpdir}/missing-fb1" \
	WAIT_ATTEMPTS=1 \
	WAIT_INTERVAL=0 \
	CON2FBMAP_BIN="${tmpdir}/bin/con2fbmap" \
	SYSTEMCTL_BIN="${tmpdir}/bin/systemctl" \
	FGCONSOLE_BIN="${tmpdir}/bin/fgconsole" \
	CHVT_BIN="${tmpdir}/bin/chvt" \
	SLEEP_BIN="${tmpdir}/bin/sleep" \
	"${helper}"

assert_not_contains '^con2fbmap ' "${command_log}"
assert_not_contains '^systemctl ' "${command_log}"
assert_not_contains '^chvt ' "${command_log}"

echo "Avaota small-screen console checks passed"
