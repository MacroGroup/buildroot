#!/bin/sh

BOARD_DIR="$(dirname $0)"

$BOARD_DIR/post-build-common.sh

install -m 0755 -D $BOARD_DIR/usb-upload-boot-ds-rk35*-evb.sh $BINARIES_DIR
install -m 0755 -D $BOARD_DIR/usb-upload-emmc-ds-rk35*-evb.sh $BINARIES_DIR

if [ ! -f $BINARIES_DIR/barebox-diasom-rk3568-som-smarc-evb.img ]; then
	cd $BINARIES_DIR
	ln -sf barebox-diasom-rk3568-som-evb.img barebox-diasom-rk3568-som-smarc-evb.img
fi

exit 0
