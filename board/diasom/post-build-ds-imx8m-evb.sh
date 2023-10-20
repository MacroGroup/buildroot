#!/bin/sh

BOARD_DIR="$(dirname $0)"

$BOARD_DIR/post-build-common.sh

install -m 0755 -D $BOARD_DIR/usb-upload-boot-ds-imx8m-evb.sh $BINARIES_DIR/usb-upload-boot.sh

exit 0
