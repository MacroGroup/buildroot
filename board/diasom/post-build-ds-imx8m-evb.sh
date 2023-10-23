#!/bin/sh

BOARD_DIR="$(dirname $0)"

$BOARD_DIR/post-build-common.sh

install -m 0755 -D $BOARD_DIR/usb-upload-boot-ds-imx8m-evb.sh $BINARIES_DIR/usb-upload-boot.sh
install -m 0755 -D $BOARD_DIR/usb-upload-emmc-ds-imx8m-evb.sh $BINARIES_DIR/usb-upload-emmc.sh

exit 0
