#!/usr/bin/env bash

set -euo pipefail

src=$(readlink -f -- "$0")
script_dir=$(cd $(dirname "$src") && pwd -P)

fastboot_bin="fastboot"
sdcard_img="ds-rk3568-smarc-evb-sdcard.img"

check_dependency() {
	if ! command -v "$1" &>/dev/null; then
		echo "Error: Required command '$1' not found in PATH" >&2
		return 1
	fi
}

check_file() {
	if [ ! -f "$1" ]; then
		echo "Error: Required file '$1' not found in $script_dir" >&2
		return 1
	fi
}

verify_requirements() {
	local error=0
	check_dependency "sudo" || error=1
	check_file "${script_dir}/${fastboot_bin}" || error=1
	check_file "${script_dir}/${sdcard_img}" || error=1
	return $error
}

main() {
	echo "This script downloads the full SD card image to the EMMC chip"
	echo "of the development board."
	echo
	echo "Prerequisites:"
	echo "1. USB cable connected between board and computer"
	echo "2. Development board in bootloader state"
	echo "3. Superuser privileges will be requested"
	echo
	read -n 1 -s -r -p "Press any key to begin (Ctrl+C to cancel)..."
	echo -e "\n\nStarting EMMC flash process..."

	sudo "${script_dir}/${fastboot_bin}" -i 7531 -S 128M flash emmc "${script_dir}/${sdcard_img}"

	echo -e "\nEMMC flash complete! You can now power cycle the board."
}

if ! verify_requirements; then
	echo -e "\nPlease ensure all requirements are met and try again." >&2
	exit 1
fi

main

exit 0
