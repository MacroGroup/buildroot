#!/usr/bin/env bash

set -e

BOARD_DIR="$(dirname "$0")"
if [ ! -d "${BOARD_DIR}" ]; then
	echo "Error: BOARD_DIR ${BOARD_DIR} does not exist" >&2
	exit 1
fi
BOARD_NAME="${2:-ds-imx8m*}"

source "${BOARD_DIR}/post-image-common.sh"
run_post_image

exit 0
