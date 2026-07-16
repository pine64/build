#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

scripts=(
	"userpatches/overlay/usr/local/bin/avaota-first-setup.sh"
	"userpatches/overlay/usr/local/bin/avaota-first-setup.sh.openclaw"
	"userpatches/overlay/usr/local/bin/avaota-first-setup.sh.picoclaw"
)

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

for script in "${scripts[@]}"; do
	test_copy="${tmpdir}/$(basename "${script}")"
	sed \
		-e '\|^\. /usr/local/lib/avaota-blz-zha\.sh$|d' \
		-e '\|^main "\$@"$|d' \
		"${script}" > "${test_copy}"

	(
		# shellcheck source=/dev/null
		source "${test_copy}"
		log() { :; }

		set +e
		run_setup "Expected failure" bash -c 'exit 42'
		status=$?
		set -e
		if [[ "${status}" -ne 42 ]]; then
			echo "${script}: run_setup returned ${status}, expected 42" >&2
			exit 1
		fi
	)

	marker="${tmpdir}/$(basename "${script}").done"
	(
		# shellcheck source=/dev/null
		source "${test_copy}"
		log() { :; }
		network_ready() { return 0; }
		setup_homeassistant() { return 42; }
		setup_zha_blz() { return 0; }
		setup_openclaw() { return 0; }
		setup_picoclaw() { return 0; }
		mark_setup_done() { touch "${marker}"; }

		set +e
		(main)
		status=$?
		set -e
		if [[ "${status}" -ne 1 ]]; then
			echo "${script}: main returned ${status}, expected 1" >&2
			exit 1
		fi
		if [[ -e "${marker}" ]]; then
			echo "${script}: completion marker created after a failed step" >&2
			exit 1
		fi
	)
done

echo "Avaota first-setup status checks passed"
