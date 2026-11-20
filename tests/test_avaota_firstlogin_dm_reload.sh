#!/bin/bash
# customize-image.sh must patch Armbian first login to daemon-reload after linking display-manager.service.
set -e
F="$(cd "$(dirname "$0")/.." && pwd)/userpatches/customize-image.sh"
grep -q 'avaota: register the alias before starting lightdm' "$F"
grep -q 'lightdm link not found' "$F"
echo PASS
