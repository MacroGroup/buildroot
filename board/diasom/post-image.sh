#!/usr/bin/env bash
# shellcheck disable=SC1091
# SPDX-License-Identifier: GPL-2.0+
# SPDX-FileCopyrightText: Alexander Shiyan <shc_work@mail.ru>

set -e

BOARD_DIR="$(dirname "$0")"
if [ ! -d "${BOARD_DIR}" ]; then
	echo "Error: BOARD_DIR ${BOARD_DIR} does not exist" >&2
	exit 1
fi

if [ -z "${BASE_DIR}" ]; then
	echo "Error: BASE_DIR is not set" >&2
	exit 1
fi

BOARD_NAME=""

if [ -f "${BASE_DIR}/board.cfg" ]; then
	if source "${BASE_DIR}/board.cfg" 2>/dev/null; then
		if [ -n "${BOARD_NAME}" ]; then
			echo "Using BOARD_NAME from board.cfg: ${BOARD_NAME}"
		fi
	fi
fi

if [ -z "${BOARD_NAME}" ]; then
	if [ -n "${2}" ]; then
		BOARD_NAME="${2}"
		echo "Using BOARD_NAME from BR2_ROOTFS_POST_SCRIPT_ARGS: ${BOARD_NAME}"
	else
		echo "Error: BOARD_NAME is not set (neither in board.cfg nor in BR2_ROOTFS_POST_SCRIPT_ARGS)" >&2
		exit 1
	fi
fi

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
