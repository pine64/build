#!/bin/bash

setup_zha_blz() {
    log "Installing BLZ support for Home Assistant ZHA..."
    local ha_config="/opt/homeassistant/config"
    mkdir -p "${ha_config}/custom_components"

    # Older images installed a forked custom ZHA component. It can lag behind the
    # Home Assistant container, so use the container's built-in ZHA and patch only
    # the BLZ radio hooks.
    if [ -d "${ha_config}/custom_components/zha" ]; then
        mkdir -p "${ha_config}/disabled_custom_components"
        rm -rf "${ha_config}/disabled_custom_components/zha"
        mv "${ha_config}/custom_components/zha" "${ha_config}/disabled_custom_components/zha"
        log "Disabled stale custom ZHA component"
    fi

    rm -rf "${ha_config}/custom_components/zha.disabled"

    log "Installing zigpy-blz into Home Assistant container..."
    docker exec homeassistant \
        python3 -m pip install --no-cache-dir --root-user-action=ignore --no-deps --upgrade \
        "zigpy-blz>=0.1.0"

    log "Patching built-in ZHA for BLZ radio support..."
    docker exec -i homeassistant python3 - <<'PY'
from pathlib import Path

import homeassistant.components.zha.radio_manager as radio_manager
import zha.application.const as zha_const
import zigpy_blz.zigbee.application as blz_application


def patch_zha_radio_type() -> None:
    path = Path(zha_const.__file__)
    text = path.read_text()

    if "import zigpy_blz.zigbee.application" not in text:
        text = text.replace(
            "import zigpy_znp.zigbee.application\n",
            "import zigpy_znp.zigbee.application\n"
            "import zigpy_blz.zigbee.application\n",
        )

    if "    blz = (" not in text:
        marker = (
            "    xbee = (\n"
            '        "XBee = Digi XBee Zigbee radios: Digi XBee Series 2, 2C, 3",\n'
            "        zigpy_xbee.zigbee.application.ControllerApplication,\n"
            "    )\n"
        )
        replacement = marker + (
            "    blz = (\n"
            '        "BLZ = Bouffalo Lab Zigbee radios: BL702/BL704/BL706",\n'
            "        zigpy_blz.zigbee.application.ControllerApplication,\n"
            "    )\n"
        )
        if marker not in text:
            raise RuntimeError("Could not find RadioType.xbee marker in zha")
        text = text.replace(marker, replacement)

    path.write_text(text)


def patch_homeassistant_zha_radio_manager() -> None:
    path = Path(radio_manager.__file__)
    text = path.read_text()

    if "    RadioType.blz," not in text:
        marker = (
            "RECOMMENDED_RADIOS = (\n"
            "    RadioType.ezsp,\n"
            "    RadioType.znp,\n"
            "    RadioType.deconz,\n"
            ")\n"
        )
        replacement = (
            "RECOMMENDED_RADIOS = (\n"
            "    RadioType.ezsp,\n"
            "    RadioType.znp,\n"
            "    RadioType.deconz,\n"
            "    RadioType.blz,\n"
            ")\n"
        )
        if marker not in text:
            raise RuntimeError("Could not find RECOMMENDED_RADIOS marker in ZHA")
        text = text.replace(marker, replacement)

    path.write_text(text)


def patch_zigpy_blz_probe_configs() -> None:
    path = Path(blz_application.__file__)
    text = path.read_text()

    if "_probe_configs = [" not in text:
        text = text.replace("_probe_config_variants = [", "_probe_configs = [")

    if "_probe_config_variants = _probe_configs" not in text:
        text = text.replace(
            "    _watchdog_period: int = 60",
            "    _probe_config_variants = _probe_configs\n\n"
            "    _watchdog_period: int = 60",
        )

    path.write_text(text)


patch_zha_radio_type()
patch_homeassistant_zha_radio_manager()
patch_zigpy_blz_probe_configs()
print("BLZ ZHA patch applied")
PY

    log "Restarting Home Assistant to load BLZ support..."
    docker restart homeassistant

    log "BLZ support installed for built-in ZHA"
}
