#!/bin/sh

. /usr/bin/recovery-functions.sh

# Waiting for key pressed for 3 seconds.
if /usr/bin/yamui-powerkey; then
	echo "Powerkey pressed, rebooting the device..."
	reboot_device
fi
