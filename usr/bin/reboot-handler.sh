#!/bin/sh
echo "Rebooting..."

sync

reboot -f
# have this as backup if reboot didn't work
/bin/echo b > /proc/sysrq-trigger

