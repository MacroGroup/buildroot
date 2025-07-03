#!/bin/sh

set -e

dmesg | grep -i sata | grep 'link up' || \
	{ echo "SATA disk is not found!"; exit 1; }

hdparm -tT /dev/sda

exit 0
