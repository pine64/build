# Avaota First Login Display Sync Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Avaota A1 first boot land on HDMI tty1 for Armbian first-login and clone the built-in panel to HDMI after desktop startup.

**Architecture:** Keep Armbian first-login unchanged. Add small systemd helpers in the image overlay, wire them from `customize-image.sh`, and adjust Avaota board boot args to prefer tty1 and disable Plymouth.

**Tech Stack:** Armbian build scripts, shell, systemd units, Xrandr, static shell tests.

---

### Task 1: First-Login Console Gate Test

**Files:**
- Create: `tests/test_avaota_firstlogin_console_gate.sh`
- Modify later: `config/boards/avaota-a1.csc`
- Modify later: `userpatches/customize-image.sh`
- Create later: `userpatches/overlay/usr/local/sbin/avaota-firstlogin-console`
- Create later: `userpatches/overlay/etc/systemd/system/avaota-firstlogin-console.service`

**Step 1: Write the failing test**

Check that boot args use `console=tty1`, disable Plymouth, force LVDS and HDMI video, install a console gate service, and wire the service from `customize-image.sh`.

**Step 2: Run test to verify it fails**

Run: `bash tests/test_avaota_firstlogin_console_gate.sh`

Expected: FAIL because the service and script do not exist yet.

**Step 3: Implement minimal code**

Add the service/script and install/enable them from `customize-image.sh`. Update `SRC_CMDLINE` in `config/boards/avaota-a1.csc`.

**Step 4: Run test to verify it passes**

Run: `bash tests/test_avaota_firstlogin_console_gate.sh`

Expected: PASS.

### Task 2: Display Clone Helper Test

**Files:**
- Create: `tests/test_avaota_display_clone.sh`
- Create later: `userpatches/overlay/usr/local/sbin/avaota-display-clone`
- Create later: `userpatches/overlay/etc/systemd/system/avaota-display-clone.service`
- Modify later: `userpatches/overlay/usr/local/sbin/avaota-hdmi-hotplug`
- Modify later: `userpatches/customize-image.sh`

**Step 1: Write the failing test**

Check that a clone helper exists, finds HDMI/internal outputs dynamically, uses `xrandr --same-as`, attempts `--scale-from`, has a systemd service after LightDM, and is installed/enabled.

**Step 2: Run test to verify it fails**

Run: `bash tests/test_avaota_display_clone.sh`

Expected: FAIL because the helper and service do not exist yet.

**Step 3: Implement minimal code**

Add a robust shell helper and systemd unit. Call the helper from the HDMI hotplug helper after enabling HDMI.

**Step 4: Run test to verify it passes**

Run: `bash tests/test_avaota_display_clone.sh`

Expected: PASS.

### Task 3: Regression Verification

**Files:**
- Test: `tests/test_avaota_firstlogin_preset.sh`
- Test: `tests/test_avaota_first_setup_background.sh`
- Test: `tests/test_avaota_hdmi_fix.sh`
- Test: new tests from Tasks 1 and 2

**Step 1: Run all focused tests**

Run:

```bash
bash tests/test_avaota_firstlogin_preset.sh
bash tests/test_avaota_first_setup_background.sh
bash tests/test_avaota_hdmi_fix.sh
bash tests/test_avaota_firstlogin_console_gate.sh
bash tests/test_avaota_display_clone.sh
```

Expected: all PASS.

**Step 2: Run syntax checks**

Run:

```bash
bash -n userpatches/customize-image.sh userpatches/overlay/usr/local/sbin/avaota-firstlogin-console userpatches/overlay/usr/local/sbin/avaota-display-clone userpatches/overlay/usr/local/sbin/avaota-hdmi-hotplug
```

Expected: exit 0.

### Task 4: Image Build and Device Verification

**Files:**
- Build output under `output/images/`

**Step 1: Build image**

Run the existing Avaota A1 desktop build command.

**Step 2: Inspect image contents**

Verify the boot args and helper files are present in the generated image.

**Step 3: Flash remote SD**

When the board is reachable from eMMC and `/dev/mmcblk0` is the SD card, write the new image to `/dev/mmcblk0`.

**Step 4: Manual boot check**

Boot from SD and verify HDMI first-login and post-login display clone behavior.
