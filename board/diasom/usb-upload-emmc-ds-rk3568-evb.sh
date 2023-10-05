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

echo "This script downloads the full SD card image to the EMMC card"
echo "of the development board."
echo "Make sure the USB cable from the development board to the computer"
echo "is connected and the development board is in the bootloader state."
echo "Attention: You will need a superuser password for the script to work!"

read -n 1 -s -p "Press any key to continue..."
echo

sudo $ROOT/fastboot -i 7531 -S 128M flash emmc $ROOT/ds-rk3568-evb-sdcard.img

exit 0
