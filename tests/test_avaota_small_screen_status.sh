#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

customize="userpatches/customize-image.sh"
helper="userpatches/overlay/usr/local/sbin/avaota-small-screen-status"
service="userpatches/overlay/etc/systemd/system/avaota-small-screen-status.service"

test -x "${helper}"
test -f "${service}"
grep -q 'python3-pil' "${customize}"
grep -q '/usr/local/sbin/avaota-small-screen-status' "${customize}"
grep -q 'systemctl enable avaota-small-screen-status.service' "${customize}"

# The page writes the framebuffer itself: no VT switching and no ordering against the display manager, both of
# which broke the boot or the HDMI desktop before.
if grep -Eq 'chvt|con2fbmap' "${helper}"; then echo "status page must not switch VTs" >&2; exit 1; fi
if grep -Eq '^(Before|After)=.*(display-manager|lightdm|getty)' "${service}"; then
	echo "status page must not be ordered against the display manager or a getty" >&2; exit 1
fi
grep -q '^WantedBy=multi-user.target' "${service}"

# Render one frame into a fake 240x135 RGB565 framebuffer when Pillow is available here.
if python3 -c 'import PIL' 2>/dev/null; then
	tmpdir="$(mktemp -d)"
	trap 'rm -rf "${tmpdir}"' EXIT
	touch "${tmpdir}/fbtest"
	FRAMEBUFFER_DEVICE="${tmpdir}/fbtest" ONCE=1 python3 "${helper}"
	test "$(stat -c %s "${tmpdir}/fbtest")" -eq $((240 * 135 * 2))
	test -n "$(tr -d '\0' < "${tmpdir}/fbtest" | head -c 1)"
fi

echo "Avaota small-screen status checks passed"
