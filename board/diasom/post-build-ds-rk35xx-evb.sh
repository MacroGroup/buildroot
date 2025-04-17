#!/bin/sh

BOARD_DIR="$(dirname $0)"

$BOARD_DIR/post-build-common.sh

install -m 0755 -D $BOARD_DIR/usb-upload-boot-ds-rk35*-evb.sh $BINARIES_DIR
install -m 0755 -D $BOARD_DIR/usb-upload-emmc-ds-rk35*-evb.sh $BINARIES_DIR

exit 0
