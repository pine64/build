# Avaota Dual Display Design

## Goal

Use HDMI as the primary Xfce desktop and the Avaota built-in panel as an
independent terminal, while keeping Armbian first login and the background
Home Assistant/OpenClaw setup usable.

## Evidence

The existing `avaota-display-clone` helper explicitly applies `--same-as` and
scales the 1920x1080 HDMI image onto the 1280x800 built-in panel. On the tested
board, both display services ran before X was ready and logged `xrandr is not
ready`, then exited successfully without retrying. The boot command line also
retained Armbian's splash arguments.

The first-setup journal shows the Home Assistant image pull started at 13:44:43
and completed at 13:59:26. `TimeoutStartSec=900` then terminated the service at
13:59:43 while BLZ dependencies were being installed. A later retry succeeded
because the Home Assistant image was cached.

## Design

Keep the first-login console gate on tty1. Keep the Plymouth package installed
because Armbian's `PLYMOUTH=no` cleanup also auto-removes LightDM on this desktop
image. Disable Plymouth at runtime with `plymouth.enable=0` and remove its splash
arguments from the board command line using a late `post_family_config` hook so
the built-in panel cannot be left displaying the boot animation. The late hook
is required because Armbian sources `common.conf` after the board file and its
default `MAIN_CMDLINE` otherwise restores the splash arguments.

Replace display cloning with an Xfce autostart helper. Running from the desktop
session guarantees that Xrandr and the user's X authority are ready. The helper
dynamically finds connected HDMI and built-in outputs, makes HDMI primary at
1920x1080, and places the built-in panel to its right at its preferred mode. It
then launches a dedicated Xfce terminal, moves it to the built-in panel, and
makes it full screen. If HDMI is absent, the helper leaves the current display
untouched.

The existing system HDMI hotplug path will call the same layout helper in
layout-only mode. It will not launch a root-owned terminal. A terminal is
created from the user session when HDMI is present during login.

Raise the background first-setup timeout from 15 minutes to one hour. Setup
remains journal-only and does not block login; failed or unusually slow runs
remain retryable through the existing timer.

## Alternatives Considered

- Keep the systemd clone service: rejected because it races X startup and
  cannot launch a terminal in the logged-in user's session.
- Configure separate Xorg screens or seats: rejected because the vendor DRM
  stack exposes both connectors through one card, making this substantially
  more fragile than an Xrandr extended desktop.
- Bind a kernel tty directly to LVDS while X owns HDMI: rejected because DRM
  framebuffer ownership conflicts with the graphical session on this kernel.

## Verification

Shell integration tests will provide deterministic Xrandr output and verify
the requested extended layout, terminal placement, no-clone policy, image
wiring, Plymouth disablement, and one-hour setup timeout. Existing first-login,
HDMI, setup isolation, BLZ/ZHA, and syntax checks must continue to pass.
