#!/usr/bin/env bash

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	echo "Error: This script is designed to be sourced, not executed directly." >&2
	exit 1
fi

genimage_type() {
	local cfg_name=""
	local board_name="$1"

	if [ -z "$board_name" ]; then
		echo "Error: board_name is not set" >&2
		return 1
	fi

	cfg_name="genimage-${board_name}.cfg"

	if [ -f "${BOARD_DIR}/${cfg_name}" ]; then
		echo "${BOARD_DIR}/${cfg_name}"
	else
		echo "Error: genimage config file '${cfg_name}' does not exist!" >&2
		return 1
	fi
}

run_post_image() {
	if [ -z "${BOARD_DIR}" ]; then
		echo "Error: BOARD_DIR is not set" >&2
		return 1
	fi

	if [ -z "${BOARD_NAME}" ]; then
		echo "Error: BOARD_NAME is not set" >&2
		return 1
	fi

	local genimage_cfg
	genimage_cfg="$(genimage_type "${BOARD_NAME}")"

	echo "Using genimage config: ${genimage_cfg}"
	support/scripts/genimage.sh -c "${genimage_cfg}"
}
