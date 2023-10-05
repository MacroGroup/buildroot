#!/bin/sh

ROOT=$(dirname -- $(readlink -f -- "$0"))

if [ ! -f $ROOT/rk-usb-loader ]; then
	echo "\"rk-usb-loader\" program is not found!"
	exit 1
fi

if [ ! -f $ROOT/barebox-diasom-rk3568-evb.img ]; then
	echo "\"barebox-diasom-rk3568-evb.img\" image is not found!"
	exit 1
fi

echo "This script loads the bootloader program into the processor"
echo "memory and runs it."
echo "To start downloading, connect the USB cable from the development"
echo "board to your computer, then turn on the board's power."
echo "Attention: You will need a superuser password for the script to work!"

read -n 1 -s -p "Press any key to continue..."
echo

sudo $ROOT/rk-usb-loader -d $ROOT/barebox-diasom-rk3568-evb.img

exit 0
