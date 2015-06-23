#!/bin/sh

while true; do
  key=$(/sbin/evkey -d -t 3000 /dev/powerkey)
  
  if [ "x${key}" == "x116" ]; then
    echo "Powerkey pressed, rebooting the device.."
    /usr/bin/reboot-handler.sh
  fi
done

