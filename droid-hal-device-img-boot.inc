# This file should be %%included into a device specific spec file
# where macros are defined:
#
# Device information:
# device: device name used in droid-hal-* package names
# mkbootimg_cmd: The device specific mkbootimg command. Last option must be
#                --output with the output image name left blank, the generic
#                part will add the image name behind mkbootimg_cmd
#

%define kernelversion %(rpm -q --qf '[%%{version}-%%{release}]' droid-hal-%{device}-kernel)
%define kernelmodulesversion %(rpm -q --qf '[%%{version}-%%{release}]' droid-hal-%{device}-kernel-modules)
%define kernelver %(rpm -ql droid-hal-%{device}-kernel-modules | sort | grep /lib/modules/ | head -1 | rev | cut -d '/' -f 1 | rev)
%define localver %(echo %{kernelver} | cut -d '-' -f1)

Name:       droid-hal-%{device}-img-boot
Summary:    Kernel boot image for %{device}
Version:    %{localver}
Release:    1
Group:      Kernel/Linux Kernel
License:    GPLv2
Source0:    %{name}-%{version}.tar.bz2

# Normal kernel build requirements
BuildRequires:  droid-hal-%{device}-kernel
BuildRequires:  droid-hal-%{device}-kernel-modules
BuildRequires:  droid-hal-%{device}-tools
BuildRequires:  initrd-helpers
BuildRequires:  hw-ramdisk
BuildRequires:  cpio
BuildRequires:  lvm2
BuildRequires:  e2fsprogs
BuildRequires:  yamui
BuildRequires:  txeireader
BuildRequires:  openssh-clients
BuildRequires:  openssh-server

# Run time requires for flashing the bootimg
Requires:	flash-partition
Requires:       droid-config-%{device}

Provides:   kernel = %{version}
Provides:   droid-hal-img-boot
Provides:   droid-hal-kernel-modules

# To overcome the jumps in revision lets bumb this version to 0.0.7 as in the past
# all versions were 0.0.6 or lower.
Provides:   droid-hal-%{device}-kernel-modules = 0.0.7
Obsoletes:  droid-hal-%{device}-kernel-modules < 0.0.7

Requires(post): kmod

BuildRequires: oneshot
Requires: oneshot
%{_oneshot_requires_post}

%description
%{summary}

%package -n droid-hal-%{device}-img-recovery

Summary:    Recovery boot image for Jolla Tablet
Provides:   droid-hal-img-recovery

%description -n droid-hal-%{device}-img-recovery
%{summary}

%prep
%setup -q -n %{name}-%{version}

%build

%if "%{kernelversion}" != "%{kernelmodulesversion}"
echo "Kernel version and module version do not match (%{kernelversion} != %{kernelmodulesversion}). Build doomed!"
exit -1
%endif

# Create a hybris-boot.img image from the zImage
cd initrd
./mksfosinitrd.sh
cd ..
%{mkbootimg_cmd} hybris-boot.img

cd initrd
./mksfosinitrd.sh recovery
cd ..
%{mkbootimg_cmd} hybris-recovery.img

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
  add-preinit-oneshot /var/lib/platform-updates/flash-bootimg.sh
fi

/sbin/depmod %{kernelver} || :

%post -n droid-hal-%{device}-img-recovery
if [ $1 -ne 1 ] ; then
  add-preinit-oneshot /var/lib/platform-updates/flash-recoveryimg.sh
fi
