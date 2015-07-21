#!/bin/sh

##############################################################################
#
# This file is part of Jolla recovery console.
# It contains common functions used by various scripts.
#
# Copyright (C) 2015 Jolla Ltd.
# Contact: Igor Zhbanov <igor.zhbanov@jolla.com>
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
##############################################################################

echo_err()
{
	echo "$@" 1>&2
}
