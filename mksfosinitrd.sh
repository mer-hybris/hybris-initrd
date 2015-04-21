#!/bin/sh

# Simple script to generate inird rootfs for Sailfish OS running on Jolla Tablet
# NOTE: if you run this locally, please do it inside Scratchbox 2 target.

# Add your tools here. They need to be present in your sb2 target.
TOOL_LIST="sbin/* debug-init /sbin/e2fsck /usr/sbin/lvm /usr/bin/yamui /sbin/resize2fs /sbin/mkfs.ext4"

# The default init script
DEF_INIT="jolla-init"

set -e

OLD_DIR=$(pwd)
TMP_DIR=/tmp/sfosinitrd

check_files()
{
	local FILES=$1
	for f in $FILES; do
		if test ! -e "$f"; then
			echo "File \"$f\" does not exist!"
			echo "Please install required RPM package or add \"$f\" manually"
			return 1
		fi
	done
	return 0
}

check_files "$TOOL_LIST" || exit 1

rm -rf "$TMP_DIR" initramfs
mkdir "$TMP_DIR"
cd "$TMP_DIR"

# Copy local files to be added to initrd. If you add more, add also to TOOL_LIST.
cp -a "$OLD_DIR"/sbin .
cp -a "$OLD_DIR"/debug-init .
# TODO, pictures for yamui: cp -a "$OLD_DIR"/res .

# Create the ramdisk
initialize-ramdisk.sh -w ./ -t "$TOOL_LIST" -i "$OLD_DIR"/"$DEF_INIT" || exit 1
moslo-build.sh -w ./ -v 2.0 || exit 1
cd "$OLD_DIR"
cp -a "$TMP_DIR"/rootfs initramfs
cp -a "$TMP_DIR"/rootfs.cpio.gz .

rm -rf "$TMP_DIR"

