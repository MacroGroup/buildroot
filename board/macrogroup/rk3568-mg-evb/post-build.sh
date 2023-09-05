#!/bin/sh
BOARD_DIR="$(dirname $0)"

install -m 0755 -D $BOARD_DIR/../common/S60alsa ${TARGET_DIR}/etc/init.d/S60alsa
install -m 0644 -D $BOARD_DIR/../common/asound.state ${TARGET_DIR}/var/lib/alsa/asound.state
