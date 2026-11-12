#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

service="userpatches/overlay/etc/systemd/system/avaota-first-setup.service"
timer="userpatches/overlay/etc/systemd/system/avaota-first-setup.timer"
scripts=(
	"userpatches/overlay/usr/local/bin/avaota-first-setup.sh"
	"userpatches/overlay/usr/local/bin/avaota-first-setup.sh.openclaw"
	"userpatches/overlay/usr/local/bin/avaota-first-setup.sh.picoclaw"
)

assert_not_contains() {
	local pattern="$1" file="$2"
	if grep -Eq -- "${pattern}" "${file}"; then
		echo "Unexpected pattern '${pattern}' in ${file}" >&2
		exit 1
	fi
}

grep -q '^StandardOutput=journal$' "${service}"
grep -q '^StandardError=journal$' "${service}"
grep -q '^Description=Avaota A1 First Boot Setup (Home Assistant + Assistant Stack)$' "${service}"
assert_not_contains 'journal\+console' "${service}"
assert_not_contains '^ExecStartPost=' "${service}"
assert_not_contains 'network-online.target' "${service}"
grep -q '^After=docker.service$' "${service}"
grep -q '^Wants=docker.service$' "${service}"
assert_not_contains '^Restart=' "${service}"
assert_not_contains '^RestartSec=' "${service}"
grep -q '^TimeoutStartSec=1h$' "${service}"

grep -q '^OnBootSec=2min$' "${timer}"
grep -q '^OnUnitInactiveSec=2min$' "${timer}"

for script in "${scripts[@]}"; do
	grep -q '^network_ready()' "${script}"
	grep -q 'Network is not ready; setup remains pending' "${script}"
	grep -q 'return 1' "${script}"
	grep -q 'if ! network_ready; then' "${script}"
	grep -q 'exit 0' "${script}"
	grep -q 'touch "${SETUP_DONE_MARKER}"' "${script}"
	assert_not_contains 'local retries=30' "${script}"
	assert_not_contains 'sleep 5' "${script}"
done

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
command_log="${tmpdir}/systemctl.log"

cat > "${tmpdir}/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${AVAOTA_SYSTEMCTL_LOG}"
exit "${AVAOTA_SYSTEMCTL_STATUS:-0}"
EOF
chmod 755 "${tmpdir}/systemctl"

for script in "${scripts[@]}"; do
	grep -q '^SETUP_DONE_MARKER=' "${script}"
	grep -q '^SYSTEMCTL_BIN=' "${script}"
	grep -q '^SETUP_TIMER_UNIT=' "${script}"

	test_copy="${tmpdir}/$(basename "${script}")"
	sed \
		-e '\|^\. /usr/local/lib/avaota-blz-zha\.sh$|d' \
		-e '\|^main "\$@"$|d' \
		"${script}" > "${test_copy}"
	marker="${tmpdir}/$(basename "${script}").done"
	: > "${command_log}"

	(
		export SETUP_DONE_MARKER="${marker}"
		export SYSTEMCTL_BIN="${tmpdir}/systemctl"
		export SETUP_TIMER_UNIT="avaota-first-setup.timer"
		export AVAOTA_SYSTEMCTL_LOG="${command_log}"
		# shellcheck source=/dev/null
		source "${test_copy}"
		log() { :; }
		mark_setup_done
	)

	test -e "${marker}"
	grep -qx -- '--no-block stop avaota-first-setup.timer' "${command_log}"

	rm -f "${marker}"
	(
		export SETUP_DONE_MARKER="${marker}"
		export SYSTEMCTL_BIN="${tmpdir}/systemctl"
		export SETUP_TIMER_UNIT="avaota-first-setup.timer"
		export AVAOTA_SYSTEMCTL_LOG="${command_log}"
		export AVAOTA_SYSTEMCTL_STATUS=1
		# shellcheck source=/dev/null
		source "${test_copy}"
		log() { :; }
		mark_setup_done
	)
	test -e "${marker}"
done

echo "Avaota first-setup background checks passed"
