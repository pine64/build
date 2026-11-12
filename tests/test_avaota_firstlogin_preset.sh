#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

customize="userpatches/customize-image.sh"

grep -q 'PRESET_USER_SHELL=bash' "${customize}"
grep -q 'touch /root/.not_logged_in_yet' "${customize}"

awk '/InstallAvaotaA1Stack\(\)/,/^} # InstallAvaotaA1Stack/' "${customize}" \
	| grep -q 'PRESET_USER_SHELL=bash'

! awk '/InstallAvaotaA1Stack\(\)/,/^} # InstallAvaotaA1Stack/' "${customize}" \
	| grep -q 'rm /root/.not_logged_in_yet'

echo "Avaota first-login preset checks passed"
