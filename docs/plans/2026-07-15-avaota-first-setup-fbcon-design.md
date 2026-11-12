# Avaota First-Setup and Small-Screen Console Design

## Goal

Make first boot non-blocking and retryable, keep XFCE on HDMI, and restore the
board's SPI display as an Armbian-style interactive framebuffer console.

## Confirmed Causes

The first-setup wrapper reads `$?` after leaving an `if` statement. At that
point Bash reports the status of the completed `if`, so a failed setup function
is logged as exit code 0. The main routine then creates the completion marker
even when Home Assistant or BLZ setup failed.

The systemd service and repeating timer both implement retries. After setup
succeeds, the marker prevents service execution, but the already-active timer
continues to wake up and produces skipped-condition journal entries.

The built-in ST7789V display is `/dev/fb1`, a 240x135 SPI framebuffer. It is
not a DRM connector and is therefore invisible to Xrandr. Treating it as
`LVDS-1` cannot produce a desktop extension or terminal. The original image
did not force `console=tty1` or fictitious LVDS video parameters; Linux fbcon
selected the framebuffer console using the native driver path.

## First-Setup Behavior

The repeating systemd timer is the single retry mechanism. It starts setup two
minutes after boot and retries after an inactive interval. The service does not
also use `Restart=on-failure`, avoiding overlapping retry schedules.

Each component returns its real exit status. A failed Home Assistant, BLZ/ZHA,
OpenClaw, or PicoClaw step leaves the completion marker absent and causes the
service to fail. A later timer run retries the idempotent setup functions.

If the network is unavailable, setup exits without marking completion. The
timer retries later without blocking login, getty, LightDM, or the desktop.

Only a run in which every component succeeds creates
`/var/lib/avaota-first-setup-done`. After creating the marker, the script stops
its timer with a non-blocking systemctl request so completed systems no longer
wake every two minutes. All progress remains in the system journal rather than
being written to the active console.

## Display Behavior

HDMI remains the primary DRM output for LightDM and XFCE. The image keeps the
HDMI configuration needed for reliable mode selection, but removes the
fictitious `video=LVDS-1` argument and the Xrandr helper that searches for an
internal DRM panel.

The ST7789V display uses Linux fbcon through `/dev/fb1`. A small-screen console
service maps a dedicated text VT to framebuffer 1 using `con2fbmap` after the
device appears. This preserves the native terminal path instead of attempting
to place an X11 terminal window on a connector that does not exist.

The normal active session remains the HDMI desktop, so the keyboard controls
XFCE by default. The user can switch to the text VT with the configured
Ctrl+Alt+Fn shortcut and return to the X session with its VT shortcut. VT input
is global; the same keyboard is not routed to both displays concurrently.

During Armbian first login, HDMI shows the standard text login flow. The
first-setup downloader runs independently in the background and cannot hold or
replace the login shell.

## Failure Handling

If `/dev/fb1` or `con2fbmap` is unavailable, the display helper logs the reason
and leaves HDMI and the normal getty path untouched. HDMI is therefore the
recovery console.

If HDMI is disconnected or X is not ready, the existing HDMI helper may retry
HDMI configuration, but it does not restart LightDM solely to configure the
SPI screen.

## Verification

Shell tests will execute the first-setup wrapper with controlled setup
functions to prove that nonzero statuses remain nonzero and prevent the marker.
Static unit tests will verify that the timer is the only retry mechanism and is
stopped only after successful completion.

Display tests will verify that no LVDS/Xrandr internal-panel assumption remains,
that HDMI configuration is retained, and that the small-screen helper maps a
dedicated VT to framebuffer 1 while failing safely when the device is absent.

After local tests and image inspection pass, hardware verification must check:

1. First login appears on HDMI without waiting for network downloads.
2. Home Assistant and the selected assistant retry after an interrupted pull.
3. The timer becomes inactive only after all setup steps succeed.
4. XFCE runs on HDMI and the ST7789V screen displays the text console.
5. Keyboard input follows the active VT and can return to the HDMI desktop.
