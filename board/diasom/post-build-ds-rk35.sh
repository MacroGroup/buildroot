#!/usr/bin/env bash

set -e

BOARD_DIR="$(dirname "$0")"
if [ ! -d "${BOARD_DIR}" ]; then
	echo "Error: BOARD_DIR ${BOARD_DIR} does not exist" >&2
	exit 1
fi

if [ -z "${2}" ]; then
	echo "Error: BOARD_NAME parameter is required (passed via BR2_ROOTFS_POST_SCRIPT_ARGS)" >&2
	exit 1
fi

BOARD_NAME="${2}"
echo "Using BOARD_NAME: ${BOARD_NAME}"

source "${BOARD_DIR}/post-build-common.sh"

run_common_tasks

if ! install_scripts "usb-upload-*-${BOARD_NAME}*.sh"; then
	echo "Warning: No scripts found for exact pattern 'usb-upload-*-${BOARD_NAME}*.sh'" >&2
fi

exit 0
