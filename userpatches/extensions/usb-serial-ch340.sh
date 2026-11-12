#!/bin/bash
#
# Armbian build extension: Enable CH340 (ch341) and CP210x USB serial drivers
# in the kernel config for Avaota A1 BLZ dongle support.
# Also enables Docker-required kernel features missing from vendor kernel.
#

function kernel_config_modifying__enable_usb_serial_ch340() {
	display_alert "Enabling USB serial drivers" "ch341 + cp210x" "info"

	# Ensure USB serial converter support is enabled
	kernel_config_set_y CONFIG_USB_SERIAL

	# Enable CH340 (ch341) driver as module
	kernel_config_set_m CONFIG_USB_SERIAL_CH341

	# Enable CP210x driver as module
	kernel_config_set_m CONFIG_USB_SERIAL_CP210X

	# Enable generic USB serial driver (useful fallback)
	kernel_config_set_m CONFIG_USB_SERIAL_GENERIC

	# Docker/container support - UTS namespace missing in vendor kernel
	display_alert "Enabling Docker-required kernel features" "UTS_NS + CGROUP_NS" "info"
	kernel_config_set_y CONFIG_UTS_NS
}
