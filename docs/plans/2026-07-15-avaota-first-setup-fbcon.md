# Avaota First-Setup and Small-Screen Console Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make first-setup accurately retry failures in the background and expose an interactive Linux console on the ST7789V framebuffer while XFCE remains on HDMI.

**Architecture:** A systemd timer is the only first-setup retry scheduler; successful setup creates a marker and stops that timer. A boot-time oneshot maps VT2 to `/dev/fb1` with `con2fbmap`, briefly activates it to render the getty, and restores the previous HDMI VT before LightDM starts.

**Tech Stack:** Bash, systemd services/timers, Linux fbcon/VT, `con2fbmap`, Armbian image customization, shell integration tests.

---

### Task 1: Preserve Setup Failure Status

**Files:**
- Create: `tests/test_avaota_first_setup_status.sh`
- Modify: `userpatches/overlay/usr/local/bin/avaota-first-setup.sh:77-89`
- Modify: `userpatches/overlay/usr/local/bin/avaota-first-setup.sh.openclaw:77-89`
- Modify: `userpatches/overlay/usr/local/bin/avaota-first-setup.sh.picoclaw:93-105`

**Step 1: Write the failing test**

For each script, source a temporary copy without its BLZ import and top-level
`main` invocation. Override setup functions, make one return 42, and assert
that `main` exits 1 without calling `mark_setup_done`. Also call `run_setup`
directly and assert that it returns 42.

**Step 2: Run test to verify it fails**

Run: `bash tests/test_avaota_first_setup_status.sh`

Expected: FAIL because `run_setup` returns 0 and the completion marker is
created after a component fails.

**Step 3: Write minimal implementation**

Capture the setup command status inside an `else` branch:

```bash
if "$@"; then
    log "${name} setup completed"
    return 0
else
    local status=$?
    log "${name} setup failed with exit code ${status}; remaining setup steps will continue"
    return "${status}"
fi
```

Apply the same fix to all three image variants.

**Step 4: Run test to verify it passes**

Run: `bash tests/test_avaota_first_setup_status.sh`

Expected: PASS for OpenClaw default, OpenClaw variant, and PicoClaw variant.

### Task 2: Make the Timer the Only Retry Scheduler

**Files:**
- Modify: `tests/test_avaota_first_setup_background.sh`
- Modify: `userpatches/overlay/etc/systemd/system/avaota-first-setup.service`
- Modify: `userpatches/overlay/etc/systemd/system/avaota-first-setup.timer`
- Modify: `userpatches/overlay/usr/local/bin/avaota-first-setup.sh`
- Modify: `userpatches/overlay/usr/local/bin/avaota-first-setup.sh.openclaw`
- Modify: `userpatches/overlay/usr/local/bin/avaota-first-setup.sh.picoclaw`

**Step 1: Extend the test and verify it fails**

Assert that the service has no `Restart=` settings, the timer keeps the
two-minute retry interval, and `mark_setup_done` invokes:

```bash
systemctl --no-block stop avaota-first-setup.timer
```

Use an injected marker path and fake systemctl binary to execute this behavior
without touching the host system.

Run: `bash tests/test_avaota_first_setup_background.sh`

Expected: FAIL because the service still has a second retry policy and a
successful script does not stop the timer.

**Step 2: Implement the timer lifecycle**

Add overridable `SETUP_DONE_MARKER`, `SYSTEMCTL_BIN`, and `SETUP_TIMER_UNIT`
variables. Create the marker, request a non-blocking timer stop, and tolerate a
timer-stop failure after logging it. Remove `Restart=on-failure` and
`RestartSec=10min` from the service.

**Step 3: Run both first-setup tests**

Run:

```bash
bash tests/test_avaota_first_setup_status.sh
bash tests/test_avaota_first_setup_background.sh
```

Expected: both PASS.

### Task 3: Define the Framebuffer Console Contract

**Files:**
- Create: `tests/test_avaota_small_screen_console.sh`
- Modify: `tests/test_avaota_firstlogin_console_gate.sh`
- Remove: `tests/test_avaota_dual_display.sh`

**Step 1: Write the failing tests**

Assert that:

- the kernel command line has HDMI and `console=tty1`, but no `video=LVDS-1`;
- image customization installs `fbset`, the small-screen helper, and its unit;
- no XDG dual-display autostart is installed;
- the helper calls `con2fbmap 2 1`, starts `getty@tty2.service`, activates VT2,
  and restores the previous VT;
- a missing framebuffer exits successfully without invoking mapping tools;
- the HDMI helper no longer calls an Xrandr internal-panel layout helper.

**Step 2: Run tests to verify they fail**

Run:

```bash
bash tests/test_avaota_small_screen_console.sh
bash tests/test_avaota_firstlogin_console_gate.sh
```

Expected: FAIL because the image still assumes `LVDS-1` and has no fbcon
mapping service.

### Task 4: Install the VT2-to-fb1 Mapping

**Files:**
- Create: `userpatches/overlay/usr/local/sbin/avaota-small-screen-console`
- Create: `userpatches/overlay/etc/systemd/system/avaota-small-screen-console.service`
- Modify: `config/boards/avaota-a1.csc`
- Modify: `userpatches/customize-image.sh`
- Modify: `userpatches/overlay/usr/local/sbin/avaota-hdmi-hotplug`
- Remove: `userpatches/overlay/usr/local/sbin/avaota-dual-display`
- Remove: `userpatches/overlay/etc/xdg/autostart/avaota-dual-display.desktop`

**Step 1: Implement the helper**

Wait for `/dev/fb1` for a bounded period. If it appears, run
`con2fbmap 2 1`, start `getty@tty2.service`, obtain the current VT, briefly
switch to VT2 so the prompt is rendered, and switch back. Log and return 0 if
the framebuffer or mapping utility is unavailable so HDMI remains usable.

All commands and paths used by the test are overridable environment variables.

**Step 2: Implement the unit and image wiring**

Run the oneshot after module loading and before LightDM/display-manager, with a
Wants dependency on `getty@tty2.service`. Install `fbset`, copy and enable the
unit, remove the XDG dual-display autostart wiring, and retain the separate HDMI
hotplug helper.

Remove only `video=LVDS-1:1280x800@60e` from the board command line. Keep the
known-working HDMI mode, tty1 console, Plymouth disablement, and Xorg HDMI
configuration.

**Step 3: Run display tests**

Run:

```bash
bash tests/test_avaota_small_screen_console.sh
bash tests/test_avaota_firstlogin_console_gate.sh
bash tests/test_avaota_hdmi_fix.sh
```

Expected: all PASS.

### Task 5: Verify the Image Source Tree

**Files:**
- Verify all modified shell scripts and units.

**Step 1: Run syntax and whitespace checks**

Run:

```bash
bash -n userpatches/customize-image.sh \
  userpatches/overlay/usr/local/bin/avaota-first-setup.sh \
  userpatches/overlay/usr/local/bin/avaota-first-setup.sh.openclaw \
  userpatches/overlay/usr/local/bin/avaota-first-setup.sh.picoclaw \
  userpatches/overlay/usr/local/sbin/avaota-firstlogin-console \
  userpatches/overlay/usr/local/sbin/avaota-hdmi-hotplug \
  userpatches/overlay/usr/local/sbin/avaota-small-screen-console
git diff --check
```

Expected: exit 0 with no output.

**Step 2: Run the full local test set**

Run: `for test in tests/test_avaota_*.sh; do bash "$test"; done`

Expected: every Avaota test reports PASS.

### Task 6: Build and Inspect Both Image Variants

**Files:**
- Build output only; do not modify build dependencies or submodule state.

**Step 1: Reconfirm build inputs**

Record `git submodule status`, relevant external repository status, and the
exact build command before building. Do not bootstrap, update submodules, or
change external SDK state.

**Step 2: Build PicoClaw and OpenClaw images**

Use the repository's established Avaota A1 release commands. Preserve existing
known-good images before replacing similarly named output.

**Step 3: Inspect built image files**

Verify the generated root filesystem contains the corrected scripts, timer,
service, framebuffer helper, and no installed dual-display XDG autostart.

### Task 7: Hardware Verification

**Step 1: Flash the test SD card only after explicit overwrite confirmation**

Boot from the new SD image while preserving the existing eMMC system.

**Step 2: Verify first boot without network**

Confirm HDMI presents Armbian first login immediately, first-setup remains
pending, and login input is not blocked.

**Step 3: Verify retry and completion with network**

Connect the network, capture `journalctl -u avaota-first-setup.service` and
`systemctl list-timers`, and prove HA plus the selected assistant complete and
the timer becomes inactive.

**Step 4: Verify display and keyboard behavior**

Confirm XFCE appears on HDMI, the ST7789V shows VT2 login, Ctrl+Alt+F2 accepts
input on the small-screen terminal, and the X VT shortcut returns control to
HDMI.
