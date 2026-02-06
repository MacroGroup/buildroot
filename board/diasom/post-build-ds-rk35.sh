#!/usr/bin/env bash

set -e

BOARD_DIR="$(dirname "$0")"
if [ ! -d "${BOARD_DIR}" ]; then
	echo "Error: BOARD_DIR ${BOARD_DIR} does not exist" >&2
	exit 1
fi
BOARD_NAME="${2:-ds-rk35}"

"${BOARD_DIR}/post-build-common.sh"

install_scripts() {
	local pattern="$1"
	local count=0

	for script in "${BOARD_DIR}"/${pattern}; do
		if [ -f "${script}" ]; then
			install -v -m 0755 "${script}" "${BINARIES_DIR}/$(basename "${script}")"
			((count++))
		fi
	done

	return ${count}
}

if ! install_scripts "usb-upload-*-${BOARD_NAME}*.sh"; then
	echo "Warning: No scripts found for exact pattern 'usb-upload-*-${BOARD_NAME}*.sh'" >&2
fi

exit 0
