#!/bin/sh
# SPDX-FileCopyrightText: 2025 Jolla Mobile Ltd
# SPDX-FileCopyrightText: 2015 - 2023 Jolla Mobile Ltd
#
# SPDX-License-Identifier: GPL-2.0-only

# Simple script to generate inird rootfs for Sailfish OS devices.
# NOTE: if you run this locally, please do it inside Scratchbox 2 target.

if [ $# -lt 2 ]; then
	echo "Usage: $0 <lib path> <compression format> [<init type>]"
	exit 1
fi
case "$1" in
	lib|lib64)
		LIB=$1
		;;
	*)
		echo "Invalid lib path '$1' (lib, lib64)"
		exit 1
		;;
esac
case "$2" in 
	"lz4")
		COMPRESSION_FORMAT=lz4
		MOSLO_COMPRESSION_PARAM=-l
		;;
	"gz")
		COMPRESSION_FORMAT=gz
		;;
	*)
		echo "Invalid compression format '$2' (gz, lz4)"
		exit 1
		;;
esac
INIT_TYPE=${3-normal}


# Add your tools here. They need to be present in your sb2 target.
# These tools will be included both to normal and recovery initrd.
TOOL_LIST="
	etc/sysconfig/*
	res/images/*
	sbin/*
	usr/bin/functions.sh
	/sbin/e2fsck
	/sbin/factory-reset-external
	/sbin/factory-reset-lvm
	/sbin/find-mmc-bypartlabel
	/usr/sbin/lvm
	/sbin/mkfs.ext4
	/sbin/resize2fs
	/usr/bin/pigz
	/usr/bin/xz
	/usr/bin/yamui
	/usr/bin/yamui-powerkey
	/usr/bin/yamui-screensaverd
	$(cat tools.files 2> /dev/null)"

# These files will be included to normal initrd only.
NORMAL_FILES="
	normal-init
	$(cat normal.files 2> /dev/null)"

# These files will be included to recovery initrd only.
RECOVERY_FILES="
	recovery-init
	etc/fstab
	etc/group
	etc/gshadow
	etc/passwd
	etc/profile
	etc/shadow
	etc/ssh/*
	etc/udhcpd.conf
	usr/bin/*
	/etc/nsswitch.conf
	/$LIB/libnss_compat.so.2
	/$LIB/libnss_files.so.2
	/usr/bin/scp
	/usr/libexec/openssh/sftp-server
	/usr/libexec/openssh/sshd-session
	/usr/libexec/openssh/sshd-auth
	/usr/sbin/sshd
	/usr/sbin/cryptsetup
	$(cat recovery.files 2> /dev/null)"

# These files will be included to vendor_boot initrd only.
VENDOR_BOOT_FILES="$(cat vendor_boot.files 2> /dev/null)"

case "$INIT_TYPE" in
	normal)
		TOOL_LIST="$TOOL_LIST $NORMAL_FILES"
		;;
	recovery)
		TOOL_LIST="$TOOL_LIST $RECOVERY_FILES"
		;;
	combined)
		# Combined normal and recovery mode initrd
		TOOL_LIST="$TOOL_LIST $NORMAL_FILES $RECOVERY_FILES"
		;;
	vendor_boot)
		# Does not include the files from boot image tools
		TOOL_LIST="$VENDOR_BOOT_FILES"
		;;
	*)
		echo "Invalid init type '$INIT_TYPE' (normal, recovery, combined, vendor_boot)"
		exit 1
		;;
esac

# Remove duplicates.
TOOL_LIST="$(echo "$TOOL_LIST" | sed -e 's/^\s*//' -e 's/\s*$//' | sort | uniq)"

# The sshd config file and keys must be accessible by files owner only.
# Git doesn't preserve full file permissions.
FIX_FILE_PERMISSIONS="
	etc/ssh/ssh_host_ed25519_key
	etc/ssh/ssh_host_rsa_key
	etc/ssh/sshd_config"

chmod 0600 $FIX_FILE_PERMISSIONS

set -e

OLD_DIR=$(pwd)
TMP_DIR=/tmp/sfosinitrd

rm -rf "$TMP_DIR"
mkdir "$TMP_DIR"
cd "$TMP_DIR"

if [ "$INIT_TYPE" != "vendor_boot" ]; then
	# Copy local files to be added to initrd
	for f in $TOOL_LIST; do
		case "$f" in
			/*)
				if [ -e "$f" ]; then
					# Absolute paths, i.e. non-local files, don't need to be copied
					continue
				else
					# but they need to exists
					echo "File '$f' does not exist!"
					echo "Please install required RPM package or add '$f' manually"
					exit 1
				fi
				;;
			res/images/*)
				# Images are copied from separate location...
				continue
				;;
			*)
				d=$(dirname "$f")
				[ "$d" != "." ] && mkdir -p "./$d"
				cp -a "$OLD_DIR"/$f "$d/"
				;;
		esac
	done
	mkdir -p res/images
	cp -a /usr/share/initrd-logos/* res/images
else 
	# Copy vendor_boot files
	if [ -d "$OLD_DIR"/lib/vendor_boot_modules ]; then
		mkdir -p lib/modules
		cp -a "$OLD_DIR"/lib/vendor_boot_modules/* lib/modules
	fi
fi

# Create the ramdisk
if [ "$INIT_TYPE" != "vendor_boot" ]; then
	initialize-ramdisk.sh -w ./ -t "$TOOL_LIST" -i "$OLD_DIR/main-init" || exit 1
	moslo-build.sh -w ./ -v 2.0 $MOSLO_COMPRESSION_PARAM || exit 1
else
	# Custom creation of vendor_boot ramdisk to prevent useless files from being added
	# to ramdisk by initialize-ramdisk.sh and moslo-build.sh which assume basic
	# filesystem structure and some files are always needed which is not the case
	# for vendor_boot. In the future initialize-ramdisk.sh and moslo-build.sh could
	# be adjusted to support also vendor_boot use case.
	WORK_DIR=./
	gen_initramfs_list.sh -o $WORK_DIR/rootfs.cpio -u squash -g squash $WORK_DIR || exit 1
	if [ "$COMPRESSION_FORMAT" = "lz4" ]; then
		lz4 -f -l -12 --favor-decSpeed $WORK_DIR/rootfs.cpio $WORK_DIR/rootfs.cpio.lz4 || exit 1
		echo Build is ready at $WORK_DIR/rootfs.cpio.lz4
	else
		gzip -n -f $WORK_DIR/rootfs.cpio || exit 1
		echo Build is ready at $WORK_DIR/rootfs.cpio.gz
	fi
fi
cd "$OLD_DIR"
cp -a "$TMP_DIR"/rootfs.cpio.$COMPRESSION_FORMAT .

rm -rf "$TMP_DIR"
