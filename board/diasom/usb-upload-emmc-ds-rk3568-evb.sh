#!/bin/sh

ROOT=$(dirname -- $(readlink -f -- "$0"))

if [ ! -f $ROOT/fastboot ]; then
	echo "\"fastboot\" program is not found!"
	exit 1
fi

if [ ! -f $ROOT/ds-rk3568-evb-sdcard.img ]; then
	echo "\"ds-rk3568-evb-sdcard.img\" image is not found!"
	exit 1
fi

#TODO
#fastboot -i 7531 -S 128M flash emmc $ROOT/ds-rk3568-evb-sdcard.img

exit 0
