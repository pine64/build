# Allwinner Cortex-A55 octa core 2/4GB RAM SoC USB3 USB-C 2x GbE LCD
BOARD_NAME="Avaota A1"
BOARD_VENDOR="allwinner"
BOARDFAMILY="sun55iw3-syterkit"
BOARD_MAINTAINER="chainsx"
INTRODUCED="2024"
KERNEL_TARGET="legacy"
BOOT_FDT_FILE="allwinner/sun55i-t527-avaota-a1.dtb"
SRC_EXTLINUX="yes"
SRC_CMDLINE="earlycon=uart8250,mmio32,0x02500000 clk_ignore_unused initcall_debug=0 console=ttyAS0,115200 loglevel=8 cma=64M init=/sbin/init"
BOOTFS_TYPE="fat"
BOOTSIZE="256"
SERIALCON="ttyAS0"
declare -g SYTERKIT_BOARD_ID="avaota-a1" # This _only_ used for syterkit-allwinner extension

function post_family_tweaks__avaota-a1() {
	display_alert "Applying boot blobs"
	cp -v "$SRC/packages/blobs/sunxi/sun55iw3/bl31.bin" "$SDCARD/boot/bl31.bin"
	cp -v "$SRC/packages/blobs/sunxi/sun55iw3/scp.bin" "$SDCARD/boot/scp.bin"
	cp -v "$SRC/packages/blobs/sunxi/sun55iw3/splash.bin" "$SDCARD/boot/splash.bin"

	display_alert "Applying wifi firmware"
	pushd "$SDCARD/lib/firmware"
	ln -s "aic8800/SDIO/aic8800D80" "aic8800d80" # use armbian-firmware
	popd

	display_alert "Applying Xorg display controller configuration"
	mkdir -p "$SDCARD/etc/X11/xorg.conf.d"
	cat <<- EOF > "$SDCARD/etc/X11/xorg.conf.d/02-sunxi-drm.conf"
		Section "ServerFlags"
		    Option "AutoAddGPU" "off"
		    Option "AutoBindGPU" "off"
		EndSection

		Section "ServerLayout"
		    Identifier "Sunxi Layout"
		    Screen 0 "Sunxi Screen"
		EndSection

		Section "OutputClass"
		    Identifier "sun4i-drm"
		    MatchDriver "sun4i-drm"
		    Driver "modesetting"
		    Option "PrimaryGPU" "true"
		EndSection

		Section "Device"
		    Identifier "sunxi-drm-card0"
		    Driver "modesetting"
		    Option "kmsdev" "/dev/dri/card0"
		    Option "AccelMethod" "none"
		    Option "ShadowFB" "true"
		    Option "PageFlip" "false"
		    Option "SWcursor" "true"
		EndSection

		Section "Screen"
		    Identifier "Sunxi Screen"
		    Device "sunxi-drm-card0"
		EndSection
	EOF

	mkdir -p "$SDCARD/usr/local/sbin"
	cat <<-'EOF' > "$SDCARD/usr/local/sbin/avaota-xorg-hdmi-config"
		#!/usr/bin/env bash
		set -euo pipefail

		conf="${XORG_CONF:-/etc/X11/xorg.conf.d/02-sunxi-drm.conf}"
		drm_sys_class="${DRM_SYS_CLASS:-/sys/class/drm}"
		selected_card=""
		fallback_card=""

		for connector in "${drm_sys_class}"/card*-HDMI-A-*; do
			[[ -e "$connector/status" ]] || continue
			base="${connector##*/}"
			card="${base%%-*}"
			[[ -n "$fallback_card" ]] || fallback_card="$card"
			if [[ "$(cat "$connector/status" 2>/dev/null || true)" == "connected" ]]; then
				selected_card="$card"
				break
			fi
		done

		selected_card="${selected_card:-${fallback_card:-card0}}"
		kmsdev="/dev/dri/${selected_card}"

		mkdir -p "$(dirname "$conf")"
		cat > "$conf" <<XORG
		Section "ServerFlags"
		    Option "AutoAddGPU" "off"
		    Option "AutoBindGPU" "off"
		EndSection

		Section "ServerLayout"
		    Identifier "Sunxi Layout"
		    Screen 0 "Sunxi Screen"
		EndSection

		Section "OutputClass"
		    Identifier "sun4i-drm"
		    MatchDriver "sun4i-drm"
		    Driver "modesetting"
		    Option "PrimaryGPU" "true"
		EndSection

		Section "Device"
		    Identifier "sunxi-drm-hdmi"
		    Driver "modesetting"
		    Option "kmsdev" "${kmsdev}"
		    Option "AccelMethod" "none"
		    Option "ShadowFB" "true"
		    Option "PageFlip" "false"
		    Option "SWcursor" "true"
		EndSection

		Section "Screen"
		    Identifier "Sunxi Screen"
		    Device "sunxi-drm-hdmi"
		EndSection
		XORG

		logger -t avaota-xorg-hdmi-config "configured Xorg kmsdev=${kmsdev}"
	EOF
	chmod 0755 "$SDCARD/usr/local/sbin/avaota-xorg-hdmi-config"

	mkdir -p "$SDCARD/etc/systemd/system/graphical.target.wants"
	cat <<- EOF > "$SDCARD/etc/systemd/system/avaota-xorg-hdmi-config.service"
		[Unit]
		Description=Configure Xorg for Avaota A1 HDMI DRM card
		Wants=systemd-udev-settle.service
		After=systemd-udev-settle.service
		Before=display-manager.service lightdm.service
		ConditionPathExistsGlob=/sys/class/drm/card*-HDMI-A-*

		[Service]
		Type=oneshot
		ExecStart=/usr/local/sbin/avaota-xorg-hdmi-config

		[Install]
		WantedBy=graphical.target lightdm.service
	EOF
	ln -sf /etc/systemd/system/avaota-xorg-hdmi-config.service "$SDCARD/etc/systemd/system/graphical.target.wants/avaota-xorg-hdmi-config.service"
	mkdir -p "$SDCARD/etc/systemd/system/lightdm.service.wants"
	ln -sf /etc/systemd/system/avaota-xorg-hdmi-config.service "$SDCARD/etc/systemd/system/lightdm.service.wants/avaota-xorg-hdmi-config.service"
}
