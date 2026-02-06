#!/usr/bin/env bash

set -e

BOARD_DIR="$(dirname "$0")"
if [ ! -d "${BOARD_DIR}" ]; then
	echo "Error: BOARD_DIR ${BOARD_DIR} does not exist" >&2
	exit 1
fi

genimage_type() {
	echo "genimage-ds-rk35xx-evb.cfg"
}

support/scripts/genimage.sh -c "${BOARD_DIR}/$(genimage_type)"

exit 0
