#!/usr/bin/env bash

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	echo "Error: This script is designed to be sourced, not executed directly." >&2
	exit 1
fi

check_required_vars() {
	for var in BINARIES_DIR TARGET_DIR HOST_DIR; do
		eval "value=\"\${$var}\""
		if [ -z "$value" ]; then
			echo "Error: $var is not set" >&2
			return 1
		fi
	done

	return 0
}

install_scripts() {
	local pattern="$1"
	local found=0

	shopt -s nullglob
	for script in "${BOARD_DIR}"/${pattern}; do
		install -v -m 0755 "${script}" "${BINARIES_DIR}/$(basename "${script}")"
		found=1
	done
	shopt -u nullglob

	return $((found == 0))
}

run_common_tasks() {
	if ! check_required_vars; then
		return 1
	fi

	if [ -d "$BINARIES_DIR" ]; then
		for overlay in "$BINARIES_DIR"/*.dtbo; do
			[ -f "$overlay" ] || continue
			filename="${overlay##*/}"
			install -m 0644 -D "$overlay" "${TARGET_DIR}/boot/${filename}"
		done
	else
		echo "Warning: BINARIES_DIR '$BINARIES_DIR' does not exist" >&2
	fi

	if [ -f "${HOST_DIR}/bin/fastboot" ]; then
		mkdir -p "$BINARIES_DIR"
		ln -sf "${HOST_DIR}/bin/fastboot" "${BINARIES_DIR}/fastboot"
	fi
}
