# Avaota First Setup Background Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Avaota first-setup run silently in the background without blocking Armbian first login or HDMI console use.

**Architecture:** Keep the existing systemd timer, but make the service journal-only and make the script quick-exit when the network is not ready. The setup script owns the done marker and only writes it after Home Assistant, BLZ/ZHA setup, and OpenClaw/PicoClaw installation all succeed.

**Tech Stack:** Bash, systemd service/timer, Armbian userpatch overlay.

---

### Task 1: Add Behavior Test

**Files:**
- Create: `tests/test_avaota_first_setup_background.sh`

**Steps:**
1. Assert the service has `StandardOutput=journal` and `StandardError=journal`.
2. Assert the service does not use `journal+console`, `ExecStartPost`, or `network-online.target`.
3. Assert each first-setup script has `network_ready`, logs a pending retry message, exits successfully when the network is absent, and touches `/var/lib/avaota-first-setup-done` itself.
4. Run the test and verify it fails before implementation.

### Task 2: Update Service And Timer

**Files:**
- Modify: `userpatches/overlay/etc/systemd/system/avaota-first-setup.service`
- Modify: `userpatches/overlay/etc/systemd/system/avaota-first-setup.timer`

**Steps:**
1. Remove console output and `ExecStartPost`.
2. Remove `network-online.target` dependency so the script controls the quick network check.
3. Keep docker ordering.
4. Tune timer to run after boot and retry periodically without blocking login.

### Task 3: Update Setup Scripts

**Files:**
- Modify: `userpatches/overlay/usr/local/bin/avaota-first-setup.sh`
- Modify: `userpatches/overlay/usr/local/bin/avaota-first-setup.sh.openclaw`
- Modify: `userpatches/overlay/usr/local/bin/avaota-first-setup.sh.picoclaw`

**Steps:**
1. Replace the 150-second wait loop with `network_ready`.
2. If the network is absent, log that setup remains pending and exit 0.
3. Touch `/var/lib/avaota-first-setup-done` only after all setup work succeeds.
4. Keep existing HA, BLZ/ZHA, and assistant install behavior.

### Task 4: Verify

**Commands:**
- `bash tests/test_avaota_first_setup_background.sh`
- `bash tests/test_avaota_hdmi_fix.sh`
- `bash -n userpatches/overlay/usr/local/bin/avaota-first-setup.sh*`
- `bash -n userpatches/customize-image.sh`

### Task 5: Rebuild And Flash

**Steps:**
1. Rebuild the openclaw image with the same mid desktop options.
2. Verify image content includes journal-only service and first-setup done marker logic.
3. Flash SD from the eMMC system once the board is booted back into eMMC and reachable over SSH.
