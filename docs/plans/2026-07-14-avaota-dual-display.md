# Avaota Dual Display Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make HDMI the primary Xfce desktop, show an independent full-screen terminal on the built-in panel, and allow first setup to run for up to one hour in the background.

**Architecture:** Replace the boot-time clone service with a user-session Xfce autostart helper that configures an extended Xrandr layout and places a terminal on the built-in panel. Reuse the helper in layout-only mode for HDMI hotplug, disable Plymouth at the board level, and retain the existing first-login console gate.

**Tech Stack:** Bash, Xrandr, wmctrl, Xfce autostart, systemd, Armbian userpatch overlay.

---

### Task 1: Add Dual Display Regression Test

**Files:**
- Delete: `tests/test_avaota_display_clone.sh`
- Create: `tests/test_avaota_dual_display.sh`

**Steps:**
1. Add a shell integration test with deterministic Xrandr, terminal, and wmctrl command shims.
2. Assert HDMI becomes primary, the built-in panel is right of HDMI, and no `--same-as` or `--scale-from` command is used.
3. Assert the terminal is launched, moved to the built-in panel, and made full screen.
4. Assert the image customization installs the helper and Xfce autostart entry but does not enable the old clone service.
5. Run the test and verify it fails before implementation.

### Task 2: Implement Session-Level Dual Display

**Files:**
- Create: `userpatches/overlay/usr/local/sbin/avaota-dual-display`
- Create: `userpatches/overlay/etc/xdg/autostart/avaota-dual-display.desktop`
- Modify: `userpatches/overlay/usr/local/sbin/avaota-hdmi-hotplug`
- Modify: `userpatches/customize-image.sh`

**Steps:**
1. Wait briefly for Xrandr, then detect HDMI and built-in outputs dynamically.
2. Configure HDMI as primary and place the built-in panel to its right.
3. In a user session, launch a dedicated Xfce terminal and use wmctrl to place and full-screen it on the built-in panel.
4. Make HDMI hotplug invoke layout-only mode and remove all clone calls.
5. Install the helper, autostart entry, and required desktop utilities in the image.
6. Run the dual-display test and verify it passes.

### Task 3: Disable Board Splash Without Removing LightDM

**Files:**
- Modify: `config/boards/avaota-a1.csc`
- Modify: `tests/test_avaota_firstlogin_console_gate.sh`

**Steps:**
1. Add failing assertions for runtime Plymouth disablement, retention of the Plymouth package policy, and removal of splash command-line arguments.
2. Keep `plymouth.enable=0`, do not set `PLYMOUTH=no`, and override `MAIN_CMDLINE` without splash parameters from the board's late `post_family_config` hook. A top-level board assignment is overwritten by `config/sources/common.conf`.
3. Run the first-login console test and verify it passes.

### Task 4: Extend First Setup Timeout

**Files:**
- Modify: `tests/test_avaota_first_setup_background.sh`
- Modify: `userpatches/overlay/etc/systemd/system/avaota-first-setup.service`

**Steps:**
1. Add a failing assertion for `TimeoutStartSec=1h`.
2. Change the service timeout from 900 seconds to one hour.
3. Run the background setup test and verify it passes.

### Task 5: Verify

**Steps:**
1. Run every `tests/test_avaota_*.sh` test.
2. Run Bash syntax checks on customization, setup, and display helpers.
3. Inspect the final diff for clone references, splash arguments, and accidental unrelated edits.
4. Build and device verification remain separate because the final display placement requires the physical HDMI and built-in panel.
