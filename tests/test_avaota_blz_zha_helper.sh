#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

helper="userpatches/overlay/usr/local/lib/avaota-blz-zha.sh"

grep -q 'Verifying zigpy-blz probe config' "${helper}"
grep -q '_probe_configs' "${helper}"
grep -q 'patch_zha_tuple("RECOMMENDED_RADIOS")' "${helper}"
grep -q 'patch_zha_tuple("AUTOPROBE_RADIOS")' "${helper}"

! grep -q 'Could not find RECOMMENDED_RADIOS marker' "${helper}"
! grep -q 'RECOMMENDED_RADIOS = (\\n' "${helper}"
! grep -q 'patch_zigpy_blz_probe_configs' "${helper}"

echo "Avaota BLZ ZHA helper checks passed"
