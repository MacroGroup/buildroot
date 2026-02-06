#!/usr/bin/env bash

set -e

BOARD_DIR="$(dirname "$0")"
if [ ! -d "${BOARD_DIR}" ]; then
	echo "Error: BOARD_DIR ${BOARD_DIR} does not exist" >&2
	exit 1
fi

genimage_type() {
	local board_name="ds-rk35xx-evb"
	local cfg_name=""

	if [ $# -gt 0 ] && [ -n "$1" ]; then
		board_name="$1"
	fi

	cfg_name="genimage-${board_name}.cfg"

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
