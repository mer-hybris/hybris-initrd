#!/bin/sh

# Simple script to generate inird rootfs for Sailfish OS devices.
# NOTE: if you run this locally, please do it inside Scratchbox 2 target.

# Add your tools here. They need to be present in your sb2 target.
# These tools will be included both to normal and recovery initrd.
TOOL_LIST="					\
	etc/sysconfig/*				\
	res/images/*				\
	sbin/*					\
	usr/bin/functions.sh			\
	/sbin/e2fsck				\
	/sbin/factory-reset-external		\
	/sbin/factory-reset-lvm			\
	/sbin/find-mmc-bypartlabel		\
	/usr/sbin/lvm				\
	/sbin/mkfs.ext4				\
	/sbin/resize2fs				\
	/usr/bin/pigz				\
	/usr/bin/xz				\
	/usr/bin/yamui				\
	/usr/bin/yamui-powerkey			\
	/usr/bin/yamui-screensaverd"

# These tools will be included to recovery initrd only.
RECOVERY_FILES="				\
	etc/fstab				\
	etc/group				\
	etc/gshadow				\
	etc/passwd				\
	etc/profile				\
	etc/shadow				\
	etc/ssh/*				\
	etc/udhcpd.conf				\
	usr/bin/*				\
	/etc/nsswitch.conf			\
	/$1/libnss_compat.so.2			\
	/$1/libnss_files.so.2			\
	/usr/bin/scp				\
	/usr/libexec/openssh/sftp-server	\
	/usr/libexec/openssh/sshd-session	\
	/usr/sbin/sshd				\
	/usr/sbin/cryptsetup"

# These tools will be included to vendor_boot initrd only.
VENDOR_BOOT_FILES=""

# The sshd config file and keys must be accessible by files owner only.
# Git doesn't preserve full file permissions.
FIX_FILE_PERMISSIONS="				\
	etc/ssh/ssh_host_ed25519_key		\
	etc/ssh/ssh_host_rsa_key		\
	etc/ssh/sshd_config"

chmod 0600 $FIX_FILE_PERMISSIONS

TOOL_LIST="$TOOL_LIST $(cat tools.files 2> /dev/null)"

shift

if test x"$1" = x"lz4"; then
	COMPRESSION_FORMAT=lz4
	MOSLO_COMPRESSION_PARAM=-l
else
	COMPRESSION_FORMAT=gz
fi

shift

if test x"$1" = x"vendor_boot"; then
	# Does not include the files from boot image tools
	TOOL_LIST="$VENDOR_BOOT_FILES_FILES $(cat vendor_boot.files 2> /dev/null)"
	DEF_INIT="jolla-init"
elif test x"$1" = x"recovery"; then
	TOOL_LIST="$TOOL_LIST $RECOVERY_FILES $(cat recovery.files 2> /dev/null)"
	DEF_INIT="recovery-init"
else
	# The default init script
	DEF_INIT="jolla-init"
fi

# Remove duplicates.
TOOL_LIST="$(echo $TOOL_LIST | sort | uniq)"

set -e

OLD_DIR=$(pwd)
TMP_DIR=/tmp/sfosinitrd

check_files()
{
	local FILES=$1
	for f in $FILES; do
		if test ! -e "$f"; then
			# skip empty images folder
			if [ "$f" = "res/images/*" ]; then
				continue
			fi

			echo "File \"$f\" does not exist!"
			echo "Please install required RPM package or add \"$f\" manually"
			return 1
		fi
	done
	return 0
}

check_files "$TOOL_LIST" || exit 1

rm -rf "$TMP_DIR"
mkdir "$TMP_DIR"
cd "$TMP_DIR"

if test x"$1" != x"vendor_boot"; then
	# Copy local files to be added to initrd. If you add more, add also to TOOL_LIST.
	cp -a "$OLD_DIR"/sbin .
	mkdir -p usr/bin
	cp -a "$OLD_DIR"/usr/bin/functions.sh usr/bin
	mkdir -p res/images
	cp -a /usr/share/initrd-logos/* res/images
	mkdir -p etc
	cp -a "$OLD_DIR"/etc/sysconfig etc
fi

# Copy recovery files
if test x"$1" = x"recovery"; then
	cp -a "$OLD_DIR"/usr/ "$OLD_DIR"/etc/ -t ./
fi

# Copy vendor_boot files
if test x"$1" = x"vendor_boot"; then
	if [ -d "$OLD_DIR"/lib/vendor_boot_modules ]; then
		mkdir -p lib/modules
		cp -a "$OLD_DIR"/lib/vendor_boot_modules/* lib/modules
	fi
fi

# Create the ramdisk
if test x"$1" != x"vendor_boot"; then
	initialize-ramdisk.sh -w ./ -t "$TOOL_LIST" -i "$OLD_DIR"/"$DEF_INIT" || exit 1
	moslo-build.sh -w ./ -v 2.0 $MOSLO_COMPRESSION_PARAM || exit 1
else
	# Custom creation of vendor_boot ramdisk to prevent useless files from being added
	# to ramdisk by initialize-ramdisk.sh and moslo-build.sh which assume basic
	# filesystem structure and some files are always needed which is not the case
	# for vendor_boot. In the future initialize-ramdisk.sh and moslo-build.sh could
	# be adjusted to support also vendor_boot use case.
	WORK_DIR=./
	gen_initramfs_list.sh -o $WORK_DIR/rootfs.cpio -u squash -g squash $WORK_DIR || exit 1
	if test x"$COMPRESSION_FORMAT" = x"lz4"; then
		lz4 -f -l -12 --favor-decSpeed $WORK_DIR/rootfs.cpio $WORK_DIR/rootfs.cpio.lz4 || exit 1
		echo Build is ready at $WORK_DIR/rootfs.cpio.lz4
	else
		gzip -f  $WORK_DIR/rootfs.cpio || exit 1
		echo Build is ready at $WORK_DIR/rootfs.cpio.gz
	fi
fi
cd "$OLD_DIR"
cp -a "$TMP_DIR"/rootfs.cpio.$COMPRESSION_FORMAT .

rm -rf "$TMP_DIR"
