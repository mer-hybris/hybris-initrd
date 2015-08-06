#!/bin/sh

##############################################################################
#
# This file is part of Jolla recovery console.
# It contains common functions used by various scripts.
#
# Copyright (C) 2015 Jolla Ltd.
# Contact: Igor Zhbanov <igor.zhbanov@jolla.com>
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

LOCKDIR="/var/run"
LOCKFILE="$LOCKDIR/recovery.lock"
LOCKINFO="$LOCKDIR/recovery.lockinfo"

echo_err()
{
	echo "$@" 1>&2
}

reboot_device()
{
	lock_exclusive # To prevent reboot while other actions are running.
	# The lock will be cleared because we store it on tmpfs, also we have
	# a line in recovery-init.

	echo "Rebooting..."
	sync
	reboot -f

	# Have this as backup if reboot didn't work.
	/bin/echo b > /proc/sysrq-trigger
}

lock_file()
{
	local ret=0
	local TEMPFILE="$LOCKDIR/_lock_.$$"
	if ! echo $$ > "$TEMPFILE" 2> /dev/null; then
		echo "Can't create file in directory $(dirname \"$1\")."
		return 2 # Internal error.
	fi

	if ! ln "$TEMPFILE" "$LOCKFILE" 2> /dev/null; then
		# For cleanup after interruption in the middle of locking.
		local pid=0$(cat "$LOCKFILE")
		if [ $pid -ne $$ ]; then
			if ! kill -0 $pid 2> /dev/null; then # Stale lock.
				rm -f "$LOCKFILE" # Will lock on next turn.
			fi

			ret=1 # Other process accessing lock information.
		fi
	fi

	rm "$TEMPFILE"
	return $ret
}

try_lock_shared()
{
	local ret=1
	if ! lock_file; then
		return 1
	fi

	if [ ! -e "$LOCKINFO" ]; then # No lock set. Locking.
		echo "1" > "$LOCKINFO"
		ret=0
	else
		local lock_info=$(cat "$LOCKINFO")
		if [ "_$lock_info" != "_exclusive-lock" ]; then
			echo $((lock_info + 1)) > "$LOCKINFO"
			ret=0 # Successfully locked.
		fi
	fi

	LOCKTYPE="shared"
	rm -f "$LOCKFILE"
	return $ret
}

try_lock_exclusive()
{
	local ret=1
	if ! lock_file; then
		return 1
	fi

	if [ ! -e "$LOCKINFO" ]; then # No lock set. Locking.
		echo "exclusive-lock" > "$LOCKINFO"
		LOCKTYPE="exclusive"
		ret=0 # Successfully locked.
	fi

	rm -f "$LOCKFILE"
	return $ret
}

lock_loop()
{
	local warning_shown=0
	while ! $1; do
		if [ $warning_shown -eq 0 ]; then
			if [ "$1" == "try_lock_shared" ]; then
				echo "Can't start shell or sshd while" \
				     "factory reset or file-system check"
				echo "is in progress. Waiting for" \
				     "operations to complete..."
			else
				echo "Can't start factory reset," \
				     "file-system check or reboot while" \
				     "other critical"
				echo "operation is in progress or shell" \
				     "or sshd is running."
				echo "To continue please exit from all" \
				     "shells, stop sshd if necessary or" \
				     "wait for"
				echo "operations to complete..."
			fi

			warning_shown=1
		fi

		sleep 1
	done

	return 0
}

lock_shared()
{
	lock_loop try_lock_shared
}

lock_exclusive()
{
	lock_loop try_lock_exclusive
}

remove_lock()
{
	rm -f "$LOCKINFO"
	rm -f "$LOCKFILE"
}

unlock_shared()
{
	lock_loop lock_file
	if [ -e "$LOCKINFO" ]; then
		local lock_info=$(cat "$LOCKINFO")
		echo $((lock_info - 1)) > "$LOCKINFO"
		if [ $lock_info -le 1 ]; then
			rm "$LOCKINFO"
		fi
	else
		echo "Warning: Can't find lock information file."
	fi

	rm -f "$LOCKFILE"
	LOCKTYPE="unlocked"
}

unlock_exclusive()
{
	lock_loop lock_file
	remove_lock
	LOCKTYPE="unlocked"
}

unlock()
{
	if [ "_$LOCKTYPE" == "_exclusive" ]; then
		unlock_exclusive
	elif [ "_$LOCKTYPE" == "_shared" ]; then
		unlock_shared
	fi
}

# Checks if we are a sole lock holder.
# There could be a race condition between checking value and doing something,
# but I don't want to keep the lock on lockinfo file for long.
is_single_user()
{
	if [ "_$LOCKTYPE" == "_exclusive" ]; then
		return 0
	fi

	lock_loop lock_file
	if [ -e "$LOCKINFO" ]; then
		local num=`cat "$LOCKINFO"`
	fi

	rm -f "$LOCKFILE"
	if [ 0$num -le 1 ]; then
		return 0
	fi

	return 1
}
