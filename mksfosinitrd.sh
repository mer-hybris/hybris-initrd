#!/bin/sh

# Simple script to generate inird rootfs for Sailfish OS devices.
# NOTE: if you run this locally, please do it inside Scratchbox 2 target.

# Add your tools here. They need to be present in your sb2 target.
# These tools will be included both to normal and recovery initrd.
TOOL_LIST="					\
	etc/sysconfig/*				\
	res/images/*				\
	sbin/*					\
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
	/lib/libnss_compat.so.2			\
	/lib/libnss_files.so.2			\
	/usr/bin/scp				\
	/usr/libexec/openssh/sftp-server	\
	/usr/sbin/sshd				\
	/usr/sbin/cryptsetup"

# The sshd config file and keys must be accessible by files owner only.
# Git doesn't preserve full file permissions.
FIX_FILE_PERMISSIONS="				\
	etc/ssh/ssh_host_ed25519_key		\
	etc/ssh/ssh_host_rsa_key		\
	etc/ssh/sshd_config"

chmod 0600 $FIX_FILE_PERMISSIONS

TOOL_LIST="$TOOL_LIST $(cat tools.files 2> /dev/null)"

OLD_DIR=$(pwd)
TMP_DIR=/tmp/sfosinitrd

if [ "$1" = "recovery" ]; then
    DEF_INIT="recovery-init"
else
    # The default init script
    DEF_INIT="jolla-init"
fi

if [ "$1" = "combined" ] || [ "$1" = "recovery" ] ; then
    TOOL_LIST="$TOOL_LIST $RECOVERY_FILES $(cat recovery.files 2> /dev/null)"
fi


set -e

rm -rf "$TMP_DIR"
mkdir "$TMP_DIR"

# Remove duplicates.
TOOL_LIST="$(echo $TOOL_LIST | sort | uniq)"

check_files()
{
	local FILES=$1
	for f in $FILES; do
		if [ ! -e "$f" ]; then
			echo "File \"$f\" does not exist!"
			echo "Please install required RPM package or add \"$f\" manually"
			return 1
		fi
	done
	return 0
}

check_files "$TOOL_LIST" || exit 1

if [ "$1" = "combined" ] ; then
    cp "$OLD_DIR"/recovery-init "$TMP_DIR"/.
fi

cd "$TMP_DIR"

# Copy local files to be added to initrd. If you add more, add also to TOOL_LIST.
cp -a "$OLD_DIR"/sbin .
cp -a "$OLD_DIR"/res .
mkdir -p etc
cp -a "$OLD_DIR"/etc/sysconfig etc

# Copy recovery files
if [ "$1" = "recovery" ] || [ "$1" = "combined" ]; then
	cp -a "$OLD_DIR"/usr/ "$OLD_DIR"/etc/ -t ./
fi

# Create the ramdisk
initialize-ramdisk.sh -w ./ -t "$TOOL_LIST" -i "$OLD_DIR"/"$DEF_INIT" || exit 1
moslo-build.sh -w ./ -v 2.0 || exit 1
cd "$OLD_DIR"
cp -a "$TMP_DIR"/rootfs.cpio.gz .

rm -rf "$TMP_DIR"
