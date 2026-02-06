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

for var in BASE_DIR BINARIES_DIR HOST_DIR TARGET_DIR; do
	eval "value=\"\${$var}\""
	if [ -z "$value" ]; then
		echo "Error: $var is not set" >&2
		exit 1
	fi
done

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

for overlay in "$BINARIES_DIR"/*.dtbo; do
	[ -f "$overlay" ] || continue
	filename="${overlay##*/}"
	install -m 0644 -D "$overlay" "${TARGET_DIR}/boot/${filename}"
done

if [ -f "${HOST_DIR}/bin/fastboot" ]; then
	mkdir -p "$BINARIES_DIR"
	ln -sf "${HOST_DIR}/bin/fastboot" "${BINARIES_DIR}/fastboot"
fi

pattern="usb-upload-*-${BOARD_NAME}*.sh"
found=0

shopt -s nullglob
for script in "${BOARD_DIR}"/${pattern}; do
	install -v -m 0755 "${script}" "${BINARIES_DIR}/$(basename "${script}")"
	found=1
done
shopt -u nullglob

if [ $found -eq 0 ]; then
	echo "Warning: No scripts found for pattern '${pattern}'" >&2
fi

exit 0
