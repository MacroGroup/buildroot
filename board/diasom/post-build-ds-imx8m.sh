#!/bin/bash

set -e

BOARD_DIR="$(dirname "$0")"
if [ ! -d "${BOARD_DIR}" ]; then
	echo "Error: BOARD_DIR '${BOARD_DIR}' does not exist" >&2
	exit 1
fi

"${BOARD_DIR}/post-build-common.sh"

install_renamed_script() {
	local src="$1"
	local dest_name="$2"

	if [ ! -f "${src}" ]; then
		echo "Error: Source script ${src} not found" >&2
		exit 1
	fi

	install -v -m 0755 "${src}" "${BINARIES_DIR}/${dest_name}"
}

install_renamed_script \
	"${BOARD_DIR}/usb-upload-boot-ds-imx8m-evb.sh" \
	"usb-upload-boot.sh"
install_renamed_script \
	"${BOARD_DIR}/usb-upload-emmc-ds-imx8m-evb.sh" \
	"usb-upload-emmc.sh"

exit 0
