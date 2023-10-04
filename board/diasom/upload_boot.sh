#!/bin/sh

echo "This script loads the bootloader program into the processor's"
echo "memory and runs it."
echo "To start downloading, connect the USB cable from the development"
echo "board to the computer, then turn on the board's power."
echo "Attention: you will need a superuser password for the script to work!"

read -n 1 -s -p "Press any key to continue..."
echo

ROOT=$(dirname -- $(readlink -f -- "$0"))

sudo $ROOT/rk-usb-loader -d $ROOT/barebox-diasom-rk3568-evb.img

exit 0
