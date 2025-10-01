#!/bin/sh
# SPDX-FileCopyrightText: 2025 Jolla Mobile Ltd
# SPDX-FileCopyrightText: 2024 Jolla.
#
# SPDX-License-Identifier: GPL-2.0-only
#
# This file is part of Jolla init.
# It contains common functions used by various scripts.

load_kernel_modules()
{
	CMD_MODPROBE="busybox-static modprobe"
	CFG_FILE=/lib/modules/modules.load.recovery

	if [ ! -f $CFG_FILE ]; then
		log_kmsg "$CFG_FILE missing, not loading kernel modules"
		return
	fi

	log_kmsg "Loading kernel modules..."
	ln -s /lib/modules "/lib/modules/$(uname -r)"

	cat $CFG_FILE | while read line; do
		set -- $line
		# Skip commented entries
		[ "$1" = "#" ] && continue
		$CMD_MODPROBE $(basename "$1" .ko)
	done
}

log_kmsg()
{
	echo "initrd: $@" > /dev/kmsg
}
