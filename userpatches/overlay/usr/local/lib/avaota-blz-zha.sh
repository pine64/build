#!/bin/bash

setup_zha_blz() {
    log "Installing BLZ support for Home Assistant ZHA..."
    local ha_config="/opt/homeassistant/config"
    mkdir -p "${ha_config}/custom_components" || return $?

    # Older images installed a forked custom ZHA component. It can lag behind the
    # Home Assistant container, so use the container's built-in ZHA and register
    # only the BLZ radio hooks.
    if [ -d "${ha_config}/custom_components/zha" ]; then
        mkdir -p "${ha_config}/disabled_custom_components" || return $?
        rm -rf "${ha_config}/disabled_custom_components/zha" || return $?
        mv "${ha_config}/custom_components/zha" "${ha_config}/disabled_custom_components/zha" || return $?
        log "Disabled stale custom ZHA component"
    fi

    rm -rf "${ha_config}/custom_components/zha.disabled" || return $?

    log "Installing latest zigpy-blz into Home Assistant container..."
    docker exec homeassistant \
        python3 -m pip install --no-cache-dir --root-user-action=ignore --no-deps --upgrade \
        "zigpy-blz @ https://github.com/bouffalolab/zigpy-blz/archive/refs/heads/main.zip" || return $?

    log "Verifying zigpy-blz probe config..."
    docker exec -i homeassistant python3 - <<'PY' || return $?
import zigpy.config
from zigpy_blz.zigbee.application import ControllerApplication

probe_configs = getattr(ControllerApplication, "_probe_configs", None)
if not probe_configs:
    raise RuntimeError("zigpy-blz ControllerApplication has no _probe_configs")

if not any(
    config.get(zigpy.config.CONF_DEVICE_BAUDRATE) == 2000000
    for config in probe_configs
):
    raise RuntimeError("zigpy-blz _probe_configs does not include baudrate 2000000")

if getattr(ControllerApplication, "_probe_config_variants", None) is not probe_configs:
    raise RuntimeError("zigpy-blz _probe_config_variants is not an alias of _probe_configs")

print("zigpy-blz probe config verified")
PY

    log "Registering BLZ radio support in built-in ZHA..."
    docker exec -i homeassistant python3 - <<'PY' || return $?
from pathlib import Path

import homeassistant.components.zha.radio_manager as radio_manager
import zha.application.const as zha_const

BLZ_IMPORT = "import zigpy_blz.zigbee.application\n"
BLZ_ENUM = (
    "    blz = (\n"
    '        "BLZ = Bouffalo Lab Zigbee radios: BL702/BL704/BL706",\n'
    "        zigpy_blz.zigbee.application.ControllerApplication,\n"
    "    )\n"
)


def insert_after_enum_block(text: str, member_name: str, new_block: str) -> str:
    if new_block in text:
        return text

    lines = text.splitlines(keepends=True)
    start_line = f"    {member_name} = (\n"

    try:
        start = lines.index(start_line)
    except ValueError as exc:
        raise RuntimeError(f"Could not find RadioType.{member_name} marker in zha") from exc

    for idx in range(start + 1, len(lines)):
        if lines[idx] == "    )\n":
            lines[idx + 1:idx + 1] = new_block.splitlines(keepends=True)
            return "".join(lines)

    raise RuntimeError(f"Could not find end of RadioType.{member_name} block in zha")


def patch_zha_radio_type() -> None:
    path = Path(zha_const.__file__)
    text = path.read_text()

    if BLZ_IMPORT not in text:
        marker = "import zigpy_xbee.zigbee.application\n"
        if marker not in text:
            raise RuntimeError("Could not find zigpy_xbee import in zha")
        text = text.replace(marker, marker + BLZ_IMPORT, 1)

    if "    blz = (" not in text:
        text = insert_after_enum_block(text, "xbee", BLZ_ENUM)

    path.write_text(text)


def patch_zha_tuple(name: str) -> None:
    path = Path(radio_manager.__file__)
    text = path.read_text()
    entry = "    RadioType.blz,\n"
    lines = text.splitlines(keepends=True)

    try:
        start = lines.index(f"{name} = (\n")
    except ValueError as exc:
        raise RuntimeError(f"Could not find {name} tuple in ZHA") from exc

    for end in range(start + 1, len(lines)):
        if lines[end] == ")\n":
            tuple_text = "".join(lines[start:end + 1])
            if entry not in tuple_text:
                lines[end:end] = [entry]
                path.write_text("".join(lines))
            return

    raise RuntimeError(f"Could not find end of {name} tuple in ZHA")


patch_zha_radio_type()
patch_zha_tuple("RECOMMENDED_RADIOS")
patch_zha_tuple("AUTOPROBE_RADIOS")
print("BLZ ZHA registration applied")
PY

    log "Restarting Home Assistant to load BLZ support..."
    docker restart homeassistant || return $?

    log "BLZ support installed for built-in ZHA"
}
