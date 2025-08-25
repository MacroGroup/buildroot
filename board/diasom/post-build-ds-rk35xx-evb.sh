#!/bin/bash

set -e

BOARD_DIR="$(dirname "$0")"
if [ ! -d "${BOARD_DIR}" ]; then
	echo "Error: BOARD_DIR ${BOARD_DIR} does not exist" >&2
	exit 1
fi

"${BOARD_DIR}/post-build-common.sh"

install_scripts() {
	local pattern="$1"
	local found=0

	for script in "${BOARD_DIR}"/${pattern}; do
		if [ -f "${script}" ]; then
			install -v -m 0755 "${script}" "${BINARIES_DIR}"
			found=1
		fi
	done

	if [ "${found}" -eq 0 ]; then
		echo "Warning: No files matching pattern '${pattern}' found in ${BOARD_DIR}" >&2
	fi
}

install_scripts "usb-upload-boot-ds-rk35*-evb.sh"
install_scripts "usb-upload-emmc-ds-rk35*-evb.sh"

exit 0
