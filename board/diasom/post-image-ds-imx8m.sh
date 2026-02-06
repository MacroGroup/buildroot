#!/usr/bin/env bash

set -e

BOARD_DIR="$(dirname "$0")"
if [ ! -d "${BOARD_DIR}" ]; then
	echo "Error: BOARD_DIR ${BOARD_DIR} does not exist" >&2
	exit 1
fi
BOARD_NAME="${2:-ds-imx8m}"

genimage_type() {
	local cfg_name=""

	if [ $# -gt 0 ] && [ -n "$1" ]; then
		BOARD_NAME="$1"
	fi

	cfg_name="genimage-${BOARD_NAME}.cfg"

	if [ -f "${BOARD_DIR}/${cfg_name}" ]; then
		echo "${BOARD_DIR}/${cfg_name}"
	else
		echo "Error: genimage config file '${cfg_name}' does not exist!" >&2
		exit 1
	fi
}

GENIMAGE_CFG="$(genimage_type "$2")"
echo "Using genimage config: ${GENIMAGE_CFG}"
support/scripts/genimage.sh -c "${GENIMAGE_CFG}"

exit 0
