#!/bin/sh

##############################################################################
#
# This file is part of Jolla init.
# It contains common functions used by various scripts.
#
# Copyright (C) 2024 Jolla.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
##############################################################################

load_kernel_modules()
{
	CMD_MODPROBE="busybox-static modprobe"
	CFG_FILE=/lib/modules/modules.load.recovery

	if [ ! -f $CFG_FILE ]; then
		return
	fi

	ln -s /lib/modules "/lib/modules/$(uname -r)"

	cat $CFG_FILE | while read line; do
		set -- $line
		# Skip commented entries
		[ "$1" = "#" ] && continue
		$CMD_MODPROBE $(basename "$1" .ko)
	done
}
