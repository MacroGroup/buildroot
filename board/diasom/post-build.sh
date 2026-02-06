#!/usr/bin/env bash

set -e

BOARD_DIR="$(dirname "$0")"
if [ ! -d "${BOARD_DIR}" ]; then
	echo "Error: BOARD_DIR ${BOARD_DIR} does not exist" >&2
	exit 1
fi

if [ -z "${2}" ]; then
	echo "Error: BOARD_NAME parameter is required (passed via BR2_ROOTFS_POST_BUILD_SCRIPT_ARGS)" >&2
	exit 1
fi

BOARD_NAME="${2}"
echo "Using BOARD_NAME: ${BOARD_NAME}"

for var in BINARIES_DIR TARGET_DIR HOST_DIR; do
	eval "value=\"\${$var}\""
	if [ -z "$value" ]; then
		echo "Error: $var is not set" >&2
		exit 1
	fi
done

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
