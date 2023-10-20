#!/bin/sh

ROOT=$(dirname -- $(readlink -f -- "$0"))

if [ ! -f $ROOT/imx-usb-loader ]; then
	echo "\"imx-usb-loader\" program is not found!"
	exit 1
fi

if [ ! -f $ROOT/barebox-diasom-imx8m-evb.img ]; then
	echo "\"barebox-diasom-imx9m-evb.img\" image is not found!"
	exit 1
fi

echo "This script loads the bootloader program into the processor"
echo "memory and runs it."
echo "To start downloading, connect the USB cable from the development"
echo "board to your computer, then turn on the board's power."
echo "Attention: You will need a superuser password for the script to work!"

read -n 1 -s -p "Press any key to continue..."
echo

sudo $ROOT/imx-usb-loader $ROOT/barebox-diasom-imx8m-evb.img

exit 0
