# BLZ ZHA Manual Auto-Detect Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure BLZ is automatically detected when a user manually adds ZHA in Home Assistant.

**Architecture:** Fix the source package (`zigpy-blz`) so zigpy's probe logic sees the
2000000 baud BLZ override. The image helper installs the latest package, verifies that
probe config, and keeps the built-in ZHA radio registration idempotent.

**Tech Stack:** Python, pytest, zigpy, Home Assistant ZHA, bash first-setup helper.

---

### Task 1: Add `zigpy-blz` Probe Config Regression Test

**Files:**
- Create: `/home/frankli/Zigbee/ZHA/zigpy-blz/tests/test_application.py`
- Verify: `/home/frankli/Zigbee/ZHA/zigpy-blz/zigpy_blz/zigbee/application.py`

**Step 1: Write the regression test**

Add tests that assert `ControllerApplication` exposes `_probe_configs`, that the
first config contains `zigpy.config.CONF_DEVICE_BAUDRATE: 2000000`, and that the
legacy `_probe_config_variants` attribute aliases the same object.

**Step 2: Run the targeted test**

Run:

```bash
cd /home/frankli/Zigbee/ZHA/zigpy-blz
python -m pytest tests/test_application.py -q
```

Expected: PASS after the implementation is present.

### Task 2: Keep Source Implementation Minimal

**Files:**
- Modify: `/home/frankli/Zigbee/ZHA/zigpy-blz/zigpy_blz/zigbee/application.py`

**Step 1: Ensure the controller defines `_probe_configs`**

The class should contain:

```python
_probe_configs = [
    {zigpy.config.CONF_DEVICE_BAUDRATE: 2000000},
]
_probe_config_variants = _probe_configs
```

**Step 2: Compile the package module**

Run:

```bash
cd /home/frankli/Zigbee/ZHA/zigpy-blz
python -m py_compile zigpy_blz/zigbee/application.py
```

Expected: exit 0.

### Task 3: Verify Image Helper Policy

**Files:**
- Verify/modify if needed: `/home/frankli/Pine64/armbian-build/userpatches/overlay/usr/local/lib/avaota-blz-zha.sh`
- Verify/modify if needed: `/home/frankli/Pine64/armbian-build/userpatches/overlay/usr/local/bin/avaota-first-setup.sh`

**Step 1: Confirm helper applies BLZ ZHA support only**

The helper should install `zigpy-blz`, verify `_probe_configs`, register
`RadioType.blz`, add BLZ to `RECOMMENDED_RADIOS` and `AUTOPROBE_RADIOS`, and restart
Home Assistant.

**Step 2: Confirm first-setup does not auto-create ZHA**

Search for Home Assistant onboarding or ZHA config-entry creation commands. Expected:
none in first-setup scripts.

### Task 4: Final Verification

Run:

```bash
cd /home/frankli/Zigbee/ZHA/zigpy-blz
python -m pytest tests/test_application.py -q
python -m py_compile zigpy_blz/zigbee/application.py

cd /home/frankli/Pine64/armbian-build
bash -n userpatches/overlay/usr/local/lib/avaota-blz-zha.sh
bash -n userpatches/overlay/usr/local/bin/avaota-first-setup.sh
rg -n "async_create_user|/api/onboarding|config_entries/flow|zha/permit" userpatches/overlay/usr/local
```

Expected: tests and syntax checks pass. The final `rg` should not show automatic
Home Assistant user creation or ZHA config-entry creation in the first-setup path.
