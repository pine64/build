#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

scripts=(
	"userpatches/overlay/usr/local/bin/avaota-first-setup.sh"
	"userpatches/overlay/usr/local/bin/avaota-first-setup.sh.openclaw"
	"userpatches/overlay/usr/local/bin/avaota-first-setup.sh.picoclaw"
)

for script in "${scripts[@]}"; do
	grep -q '^run_setup()' "${script}"
	grep -q '^    local setup_failed=0$' "${script}"
	grep -q 'run_setup "Home Assistant" setup_homeassistant' "${script}"
	grep -q 'run_setup "BLZ/ZHA" setup_zha_blz' "${script}"
	grep -q 'if \[ "${setup_failed}" -ne 0 \]; then' "${script}"
	grep -q 'exit 1' "${script}"

	! grep -q '^    setup_homeassistant$' "${script}"
	! grep -q '^    setup_zha_blz$' "${script}"
done

grep -q 'run_setup "OpenClaw" setup_openclaw' "userpatches/overlay/usr/local/bin/avaota-first-setup.sh"
grep -q 'run_setup "OpenClaw" setup_openclaw' "userpatches/overlay/usr/local/bin/avaota-first-setup.sh.openclaw"
grep -q 'run_setup "PicoClaw" setup_picoclaw' "userpatches/overlay/usr/local/bin/avaota-first-setup.sh.picoclaw"

! grep -q '^    setup_openclaw$' "userpatches/overlay/usr/local/bin/avaota-first-setup.sh"
! grep -q '^    setup_openclaw$' "userpatches/overlay/usr/local/bin/avaota-first-setup.sh.openclaw"
! grep -q '^    setup_picoclaw$' "userpatches/overlay/usr/local/bin/avaota-first-setup.sh.picoclaw"

echo "Avaota first-setup step isolation checks passed"
