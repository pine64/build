# Avaota First Login Display Sync Design

## Goal

Make a fresh Avaota A1 desktop image boot into an immediately usable HDMI console for Armbian first-login, then start the desktop after first-login completes. Keep the built-in LVDS panel visually aligned with HDMI once Linux/Xorg controls both displays.

## Approach

Use two small boot/display helpers rather than changing Armbian first-login itself.

1. Kernel boot args should prefer the physical console path: `console=tty1`, forced HDMI mode, forced LVDS mode, and Plymouth disabled. This removes the splash layer that can leave HDMI black until the user manually switches VTs.
2. A first-login console gate runs only while `/root/.not_logged_in_yet` exists. It stops any display manager that might have been enabled accidentally, quits Plymouth, restarts `getty@tty1`, and switches the foreground VT to tty1.
3. Desktop startup remains Armbian-native. `armbian-firstlogin` still creates the user and starts LightDM after the user setup is complete.
4. A display clone helper runs after LightDM/Xorg is available. It uses `xrandr` to find connected HDMI and connected internal panel outputs such as LVDS/eDP/DSI, then clones internal panels to the HDMI output. When supported, it uses `--scale-from` so a smaller internal panel shows the same content as the HDMI desktop instead of only the top-left corner.

## Boundaries

The bootloader splash may still appear briefly before Linux starts. The target behavior is that Linux first-login and the desktop do not leave the small panel stuck on a stale boot splash. Full pre-kernel mirroring is outside this change.

## Risks

The exact internal connector name must come from DRM/Xrandr at runtime, so the clone helper must be dynamic. If the display driver does not support scaling, the helper falls back to a plain clone using `--same-as`.

## Verification

Static tests check the boot args, service units, install wiring, and helper behavior. Device verification requires booting the produced image and confirming:

- HDMI first lands on tty1 without pressing `Ctrl+Alt+F1`.
- Armbian first-login runs on HDMI.
- After user creation, LightDM/XFCE starts.
- `xrandr --query` shows HDMI and LVDS/eDP/DSI active, with the internal panel positioned `same-as` HDMI.
