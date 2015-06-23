#!/bin/sh
echo "Rebooting..."

# Start red led to indicate that we are shutting down
/usr/bin/led-helper.sh 255 0 0 1000 0

# Give some time for red led to show to user
sleep 2

sync

reboot -f
# have this as backup if reboot didn't work
/bin/echo b > /proc/sysrq-trigger

