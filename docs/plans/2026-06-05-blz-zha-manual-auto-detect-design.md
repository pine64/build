# BLZ ZHA Manual Auto-Detect Design

## Goal

Make the release image support BLZ in Home Assistant's normal manual ZHA add flow.
The user should be able to complete Home Assistant onboarding, add the ZHA integration,
select the BLZ USB serial device, and have ZHA detect the BLZ radio at 2000000 baud.

## Scope

This design intentionally does not create a Home Assistant user, create a ZHA config
entry, form a Zigbee network, or open permit join automatically. The BLZ dongle uses a
generic CH340 USB serial ID, so automatic USB-to-ZHA creation would risk claiming
unrelated serial devices.

## Approach

`zigpy-blz` must expose zigpy's real probe override attribute, `_probe_configs`, with
the BLZ 2000000 baud setting. The image helper installs the latest package and verifies
that probe config before registering BLZ in Home Assistant's built-in ZHA.

The Armbian first-setup helper continues to install `zigpy-blz` into the Home Assistant
container and patch built-in ZHA to register `RadioType.blz` as a recommended radio.
The release notes and logs should describe this as manual ZHA add with automatic BLZ
radio detection, not full automatic Zigbee setup.

## Verification

Package verification:

- `zigpy_blz.zigbee.application.ControllerApplication._probe_configs` exists.
- `_probe_configs` contains `baudrate: 2000000`.
- `_probe_config_variants` remains an alias for compatibility.

Image/helper verification:

- `avaota-first-setup.sh` calls `setup_zha_blz`.
- `setup_zha_blz` installs `zigpy-blz`, verifies `_probe_configs`, registers
  `RadioType.blz`, and marks it recommended/autoprobe-capable.
- No script auto-creates Home Assistant users or ZHA config entries.
