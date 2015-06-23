#!/bin/sh

while true; do
  key=$(/sbin/evkey -d -t 3000 /dev/input/event6)
  
  if [ "x${key}" == "x116" ]; then
    echo "Powerkey pressed, rebooting the device.."
    /usr/bin/reboot-handler.sh
  fi
done

