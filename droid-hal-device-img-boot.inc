# This file should be %%included into a device specific spec file
# where macros are defined:
#
# Device information:
# device:        device name used in droid-hal-* package names
# mkbootimg_cmd: The device specific mkbootimg command. Last option must be
#                --output with the output image name left blank, the generic
#                part will add the image name behind mkbootimg_cmd.
#
#                NOTE! Use "--ramdisk %%{initrd} --kernel %%{kernel} --dt
#                %%{devicetree}" to build with the standard binaries from
#                droid-hal-device kernel package.
#
# root_part_label:    Sailfish OS partition label, single string
# factory_part_label: Factory image partition label, single string
#
# battery_capacity_file:      Path to read current battery charge from.
# battery_capacity_threshold: Battery threshold for factory reset [0, 100].
#                             Default 0 (no threshold).
#
# initrd_use_lz4:             Use lz4 compression for initrd instead of gzip
#
# initrd_env_vars:            Pass the list of variables to /etc/sysconfig/init
#                             Define as follows (deduplicate percentage sign):
#                             %%define initrd_env_vars \
#                             FOO=bar\
#                             XYZ=123\
#                             %%{nil}
#
# Adding device specific files to initrd folder:
#
# Create a folder named initrd-%%{device} and copy the overriding files there.
# During build time, the files from the device specific folder will be copied
# over the standard initrd folder.
#
# Adding tools to basic set of initrd / recovery:
#
# Add file list of needed tool paths to initrd-%%{device}/tools.files or
# initrd-%%{device}/recovery.files files. It will be amended to the list of
# installed files when mksfosinitrd.sh is run. Remember to have the actual
# tool binaries to be installed in either sb2 target or in initrd-%%{device}/
# For files in sb2 / OBS target you naturally need to add BuildRequires in the
# device specific spec file to get the tools included.
#
# E.g. Adding cryptsetup: echo "/sbin/cryptsetup" > initrd-%%{device}/tools.files
# And then add "BuildRequires: cryptsetup" to spec file.
#
# Or for local tool: echo "sbin/mytool" > initrd-%%{device}/recovery.files
# And then copy mytool to initrd-%%{device}/sbin/mytool. Please note the missing
# leading / in local tools, as they will be copied with relative path.
#

%define _local_build_dir buildtmp
%define _local_initrd_dir %{_local_build_dir}/initrd
%if 0%{?initrd_use_lz4:1}
%define initrd %{_local_initrd_dir}/rootfs.cpio.lz4
%define compression_format lz4
%else
%define initrd %{_local_initrd_dir}/rootfs.cpio.gz
%define compression_format gz
%endif

%define kernelversion %(rpm -q --qf '[%%{version}-%%{release}]' droid-hal-%{device}-kernel)
%define kernelmodulesversion %(rpm -q --qf '[%%{version}-%%{release}]' droid-hal-%{device}-kernel-modules)
%define kernelver %(rpm -ql droid-hal-%{device}-kernel-modules | sort | grep /lib/modules/ | head -1 | rev | cut -d '/' -f 1 | rev)
%define localver %(echo "%{kernelver}" | cut -d '-' -f1 | cut -d '+' -f1)
%define kernel /boot/kernel-%{kernelver}
%define devicetree /boot/dt.img

# Ensure 'rpmspec' can be used to query BuildRequires
%if "%{localver}" == ""
%define localver THIS_SHOULD_NOT_APPEAR_ANYWHERE_IN_THE_BUILD_ARTIFACTS
%endif

Name:       droid-hal-%{device}-img-boot
Summary:    Kernel boot image for %{device}
%if 0%{?_obs_build_project:1}
Version:    0.0.1
%else
Version:    %{localver}
%endif
Release:    1
License:    GPLv2
Source0:    %{name}-%{version}.tar.bz2

# Normal kernel build requirements
BuildRequires:  droid-hal-%{device}-kernel
BuildRequires:  droid-hal-%{device}-kernel-modules
BuildRequires:  droid-hal-%{device}-tools
BuildRequires:  initrd-helpers
BuildRequires:  initrd-logos
BuildRequires:  cpio
BuildRequires:  lvm2
%if 0%{?initrd_use_lz4:1}
BuildRequires:  hw-ramdisk >= 1.1.6
BuildRequires:  lz4
%else
BuildRequires:  hw-ramdisk
%endif
BuildRequires:  e2fsprogs
BuildRequires:  yamui
BuildRequires:  openssh-clients
BuildRequires:  openssh-server

# mkbootimg needs python3
BuildRequires:  python3-base

# tools
Buildrequires:  coreutils
BuildRequires:  cryptsetup
BuildRequires:  sed

%if 0%{?_obs_build_project:1}
%ifarch %{ix86}
# /boot
BuildRequires: sudo-for-abuild
%endif
%endif

# Run time requires for flashing the bootimg
Requires:       droid-config-flashing

Provides:   kernel = %{version}
Provides:   droid-hal-img-boot
Provides:   droid-hal-kernel-modules

# The expectation is that dhd based modules are 0.0.* versioned, while
# this kernel package is 3.10.* or later versioned. Below will ensure
# any old dhd based module package gets obsoleted.
Provides:   droid-hal-%{device}-kernel-modules = %{version}
Obsoletes:  droid-hal-%{device}-kernel-modules < %{version}

Requires(post): kmod

BuildRequires: oneshot
Requires: oneshot
%{_oneshot_requires_post}

%description
%{summary}

%package -n droid-hal-%{device}-img-recovery

Summary:    Recovery boot image for Sailfish OS devices
Provides:   droid-hal-img-recovery

# Run time requires for flashing the recovery image
Requires:       droid-config-flashing

%description -n droid-hal-%{device}-img-recovery
%{summary}

%prep
%setup -q -n %{name}-%{version}

%build
%if "%{kernelversion}" != "%{kernelmodulesversion}"
echo "Kernel version and module version do not match (%{kernelversion} != %{kernelmodulesversion}). Build doomed!"
exit -1
%endif

# HACK for mb2 not using separate build dir, so let's create our own...
rm -rf %{_local_build_dir}
mkdir -p %{_local_initrd_dir}
cp -af initrd/* %{_local_initrd_dir}

# Copy over any device specific override initrd files
# NOTE: We do this in build section to allow local mb2 build to work.
if test -d initrd-%{device}; then
    cp -af initrd-%{device}/* %{_local_initrd_dir}/
fi

# modify partition labels
%if 0%{!?root_part_label:1}
%define root_part_label sailfish
%endif

%if 0%{!?factory_part_label:1}
%define factory_part_label fimage
%endif

%if 0%{!?external_media_devices:1}
%define external_media_devices /dev/mmcblk[1-9]*p[1-9]*
%endif

%if 0%{!?lvm_root_size:1}
%define lvm_root_size 2500
%endif
INIT_FILE=%{_local_initrd_dir}/etc/sysconfig/init
sed --in-place 's|@LVM_ROOT_PART_SIZE@|%{lvm_root_size}|' $INIT_FILE

sed --in-place 's|@PHYSDEV_PART_LABEL@|%{root_part_label}|' %{_local_initrd_dir}/etc/sysconfig/partitions
sed --in-place 's|@FIMAGE_PART_LABEL@|%{factory_part_label}|' %{_local_initrd_dir}/etc/sysconfig/partitions
sed --in-place 's|@EXTERNAL_MEDIA_DEVICES@|%{external_media_devices}|' %{_local_initrd_dir}/etc/sysconfig/partitions

# modify display settings
%if 0%{!?display_brightness_path:1}
%define display_brightness_path /sys/class/backlight/intel_backlight/brightness
%endif

%if 0%{!?display_brightness:1}
%define display_brightness 0
%endif

sed --in-place 's|@DISPLAY_BRIGHTNESS_PATH@|%{display_brightness_path}|' %{_local_initrd_dir}/etc/sysconfig/display
sed --in-place 's|@DISPLAY_BRIGHTNESS@|%{display_brightness}|' %{_local_initrd_dir}/etc/sysconfig/display

%if 0%{!?battery_capacity_file:1}
%define battery_capacity_file "/sys/class/power_supply/*_battery/capacity"
%endif

%if 0%{!?battery_capacity_threshold:1}
%define battery_capacity_threshold 0
%endif

sed --in-place 's|@BATTERY_CAPACITY_FILE@|%{battery_capacity_file}|' %{_local_initrd_dir}/etc/sysconfig/recovery
sed --in-place 's|@BATTERY_CAPACITY_THRESHOLD@|%{battery_capacity_threshold}|' %{_local_initrd_dir}/etc/sysconfig/recovery

sed --in-place 's|@LIB_DIR@|%{_libdir}|' %{_local_initrd_dir}/usr/bin/recovery-menu-devicelock

# Add device-specific environment variables from droid-hal-$DEVICE-img-boot.spec to /etc/sysconfig/init
%if 0%{?initrd_env_vars:1}
cat <<EOF >> $INIT_FILE
%{?initrd_env_vars}
EOF
%endif

# Create a hybris-boot.img image from the zImage
%if 0%{?_obs_build_project:1}
%ifarch %{ix86}
sudo chmod 755 /boot
%endif
%endif
pushd %{_local_initrd_dir}
./mksfosinitrd.sh %{_lib} %{compression_format}
popd
%{mkbootimg_cmd} hybris-boot.img

pushd %{_local_initrd_dir}
./mksfosinitrd.sh %{_lib} %{compression_format} recovery
popd
%{mkbootimg_cmd} hybris-recovery.img

rm -rf %{_local_build_dir}

%install
rm -rf %{buildroot}

# /boot
install -D -m 644 hybris-boot.img %{buildroot}/boot/hybris-boot.img
install -D -m 644 hybris-recovery.img %{buildroot}/boot/hybris-recovery.img

# /lib/modules
mkdir -p %{buildroot}/lib/modules
cp -a /lib/modules/%{kernelver} %{buildroot}/lib/modules

touch %{buildroot}/lib/modules/%{kernelver}/{modules.order,modules.builtin}

%files
%defattr(-,root,root,-)
/boot/hybris-boot.img
%defattr(644,root,root,-)
/lib/modules/%{kernelver}

%files -n droid-hal-%{device}-img-recovery
%defattr(-,root,root,-)
/boot/hybris-recovery.img

%post
# When doing install that is done during the image creation thus we don't add
# the oneshot on install but on all other cases.
if [ $1 -ne 1 ] ; then
  add-preinit-oneshot /var/lib/platform-updates/flash-bootimg.sh || :
fi

/sbin/depmod %{kernelver} || :

%post -n droid-hal-%{device}-img-recovery
if [ $1 -ne 1 ] ; then
  add-preinit-oneshot /var/lib/platform-updates/flash-recoveryimg.sh || :
fi
