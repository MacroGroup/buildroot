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

cfg_pattern="genimage-${BOARD_NAME}.cfg"
configs=()

shopt -s nullglob
for cfg in "${BOARD_DIR}"/${cfg_pattern}; do
	if [ -f "$cfg" ]; then
		configs+=("$cfg")
	fi
done
shopt -u nullglob

if [ ${#configs[@]} -eq 0 ]; then
	echo "Error: No genimage config files found for pattern '${cfg_pattern}'" >&2
	exit 1
fi

for cfg in "${configs[@]}"; do
	echo ""
	echo "Processing: $(basename "$cfg")"
	support/scripts/genimage.sh -c "${cfg}"
done

exit 0
