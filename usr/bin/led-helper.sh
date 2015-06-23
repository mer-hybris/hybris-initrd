#!/bin/sh

####################################################################################
#
# This file is part of Jolla recovery console
#
# Copyright (C) 2014 Jolla Ltd.
# Contact: Simo Piiroinen <simo.piiroinen@jolla.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
####################################################################################

R=/sys/class/leds/led:rgb_red
G=/sys/class/leds/led:rgb_green
B=/sys/class/leds/led:rgb_blue

set_led() { # <channel> <value> <on> <off>
  echo "$3" > "$1/blink_delay_on"
  echo "$4" > "$1/blink_delay_off"
  echo "$2" > "$1/brightness"
}

if [ "$#" -ne 5 ]; then
  cat <<-EOF
	Usage:
	    $0 <red_value> <green_value> <blue_value> <on_ms> <off_ms>

	Notes:
	    The rgb values must be in 0 to 255 range.

	    Use non-zero on_ms and off_ms values to make the led blink.

	    If blinking is utilized, rgb values are taken as either
	    0 or 255, i.e. only 7 colors can be used.
	EOF
  exit 1
fi

# reset to off
set_led $R 0 0 0
set_led $G 0 0 0
set_led $B 0 0 0

# give kernel side 10ms to finish async
# activity related to pattern change ...
sleep 0.01

# ... before starting the new pattern
set_led $R $1 $4 $5
set_led $G $2 $4 $5
set_led $B $3 $4 $5

