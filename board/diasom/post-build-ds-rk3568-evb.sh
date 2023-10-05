#!/bin/sh

BOARD_DIR="$(dirname $0)"

$BOARD_DIR/post-build-common.sh

ln -sf $HOST_DIR/bin/fastboot $BINARIES_DIR/fastboot

install -m 0755 -D $BOARD_DIR/usb-upload-boot-ds-rk3568-evb.sh $BINARIES_DIR/usb-upload-boot.sh
install -m 0755 -D $BOARD_DIR/usb-upload-emmc-ds-rk3568-evb.sh $BINARIES_DIR/usb-upload-emmc.sh

exit 0
